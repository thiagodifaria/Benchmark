#!/bin/bash

SCALE_FACTOR=1 # this controls the intensity of the i/o operations

# detect if we're running on windows/mingw64
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$MINGW_CHOST" ]]; then
    IS_WINDOWS=true
    EXE_EXT=".exe"
    PYTHON_CMD="python"
    CP_SEP=";" # classpath separator for windows
    echo "Detected Windows/MINGW64 environment"
else
    IS_WINDOWS=false
    EXE_EXT=""
    PYTHON_CMD="python3"
    CP_SEP=":" # classpath separator for unix-like
    echo "Detected Unix-like environment"
fi

# check if all the commands like 'go', 'rustc', and 'hyperfine' exist
echo "Checking if all required tools are installed"
TOOLS=("$PYTHON_CMD" "javac" "java" "gcc" "g++" "go" "rustc" "cargo" "julia" "nim" "hyperfine" "curl")
all_tools_found=true
for tool in "${TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo "Error: Command not found -> $tool. Please install it first."
    all_tools_found=false
  fi
done

# check for clang as alternative to gcc for better vectorization
CLANG_AVAILABLE=false
if command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
    CLANG_AVAILABLE=true
    echo "Clang detected - will use for better I/O optimization"
fi

if [ "$all_tools_found" = false ]; then
    echo "Stopping script because some tools are missing."
    exit 1
fi
echo "All tools found. Let's continue."
echo ""

# download third-party libraries if they are missing
echo "Handling dependencies..."
mkdir -p libs

# c++: download nlohmann/json header
JSON_HPP="libs/json.hpp"
if [ ! -f "$JSON_HPP" ]; then
    echo "Downloading nlohmann_json for C++..."
    curl -sL "https://github.com/nlohmann/json/releases/download/v3.11.3/json.hpp" -o "$JSON_HPP"
fi

# java: download gson and apache commons-csv jars
GSON_JAR="libs/gson.jar"
COMMONS_CSV_JAR="libs/commons-csv.jar"
if [ ! -f "$GSON_JAR" ]; then
    echo "Downloading Gson for Java..."
    curl -sL "https://repo1.maven.org/maven2/com/google/code/gson/gson/2.10.1/gson-2.10.1.jar" -o "$GSON_JAR"
fi
if [ ! -f "$COMMONS_CSV_JAR" ]; then
    echo "Downloading Commons-CSV for Java..."
    curl -sL "https://repo1.maven.org/maven2/org/apache/commons/commons-csv/1.10.0/commons-csv-1.10.0.jar" -o "$COMMONS_CSV_JAR"
fi

# rust: create a cargo.toml file to handle dependencies
CARGO_TOML="Cargo.toml"
echo "Creating Cargo.toml for Rust dependencies..."
echo '[package]' > $CARGO_TOML
echo 'name = "io_bench"' >> $CARGO_TOML
echo 'version = "0.1.0"' >> $CARGO_TOML
echo 'edition = "2021"' >> $CARGO_TOML
echo '' >> $CARGO_TOML
echo '[[bin]]' >> $CARGO_TOML
echo 'name = "io_bench"' >> $CARGO_TOML
echo 'path = "io.rs"' >> $CARGO_TOML
echo '' >> $CARGO_TOML
echo '[dependencies]' >> $CARGO_TOML
echo 'serde = { version = "1.0", features = ["derive"] }' >> $CARGO_TOML
echo 'serde_json = "1.0"' >> $CARGO_TOML
echo 'csv = "1.1"' >> $CARGO_TOML
echo 'memmap2 = "0.9"' >> $CARGO_TOML
echo 'rand = "0.8"' >> $CARGO_TOML
echo ""

# generate the data files needed for the benchmarks
echo "Generating test data (this might take a moment)..."
$PYTHON_CMD dependencies/dependencies.py $SCALE_FACTOR
echo "Data generation complete"
echo ""

# this is where we compile everything, with checks after each command
echo "Compiling all languages"

echo "Compiling Java code..."
javac -cp ".${CP_SEP}${GSON_JAR}${CP_SEP}${COMMONS_CSV_JAR}" io.java
if [ $? -ne 0 ]; then echo "Java compilation failed. Stopping."; exit 1; fi

# for c, use clang if available for better auto-vectorization, otherwise gcc with maximum optimization  
echo "Compiling C code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang for better I/O optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -o "io_c${EXE_EXT}" io.c -lm
    else
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -o "io_c${EXE_EXT}" io.c -lm
    fi
else
    echo "Using GCC with enhanced optimization flags..."
    if [ "$IS_WINDOWS" = true ]; then
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "io_c${EXE_EXT}" io.c -lm
    else
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "io_c${EXE_EXT}" io.c -lm
    fi
fi
if [ $? -ne 0 ]; then echo "C compilation failed. Stopping."; exit 1; fi

# for cpp, use clang++ if available for better optimization
echo "Compiling C++ code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang++ for better I/O optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -I./libs -static -static-libgcc -static-libstdc++ -o "io_cpp${EXE_EXT}" io.cpp
    else
        clang++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -I./libs -static -o "io_cpp${EXE_EXT}" io.cpp
    fi
else
    echo "Using G++ with enhanced optimization flags..."
    if [ "$IS_WINDOWS" = true ]; then
        g++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -I./libs -static -static-libgcc -static-libstdc++ -o "io_cpp${EXE_EXT}" io.cpp
    else
        g++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -I./libs -static -o "io_cpp${EXE_EXT}" io.cpp
    fi
fi
if [ $? -ne 0 ]; then echo "C++ compilation failed. Stopping."; exit 1; fi

echo "Compiling Go code..."
go build -ldflags="-s -w" -gcflags="-B" -o "io_go${EXE_EXT}" io.go
if [ $? -ne 0 ]; then echo "Go compilation failed. Stopping."; exit 1; fi

# julia doesn't need compilation, it's JIT compiled
echo "Julia ready (JIT compiled at runtime)"

# nim with optimized flags - use --mm:orc to avoid ARC threading issues
echo "Compiling Nim code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Nim using Clang backend for better optimization..."
    nim c -d:release -d:lto --opt:speed --mm:orc --cc:clang --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops" --passL:"-flto" -o:"io_nim${EXE_EXT}" io.nim
else
    echo "Nim using GCC backend with enhanced flags..."
    nim c -d:release -d:lto --opt:speed --mm:orc --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops" --passL:"-flto" -o:"io_nim${EXE_EXT}" io.nim
fi
if [ $? -ne 0 ]; then echo "Nim compilation failed. Stopping."; exit 1; fi

echo "Compiling Rust code with Cargo..."
cargo build --release --quiet
if [ $? -ne 0 ]; then echo "Rust compilation failed. Stopping."; exit 1; fi
cp "target/release/io_bench${EXE_EXT}" "io_rust${EXE_EXT}"

echo "All compilations were successful!"
echo ""

# running the comprehensive i/o performance test
echo "Running the comprehensive I/O performance test!"
echo "Languages: C, C++, Go, Java, Julia, Nim, Python, Rust"
echo "Operations: File Processing, CSV Manipulation, JSON Parsing"
echo "Scale factor ${SCALE_FACTOR} selected for intensive performance measurement"
echo ""

# Build command array based on OS
if [ "$IS_WINDOWS" = true ]; then
    C_CMD="./io_c.exe ${SCALE_FACTOR}"
    CPP_CMD="./io_cpp.exe ${SCALE_FACTOR}"
    GO_CMD="./io_go.exe ${SCALE_FACTOR}"
    RUST_CMD="./io_rust.exe ${SCALE_FACTOR}"
    NIM_CMD="./io_nim.exe ${SCALE_FACTOR}"
    JAVA_CMD="java -server -cp \".${CP_SEP}${GSON_JAR}${CP_SEP}${COMMONS_CSV_JAR}\" io ${SCALE_FACTOR}"
    JULIA_CMD="julia --project=. --optimize=3 --check-bounds=no io.jl ${SCALE_FACTOR}"
else
    C_CMD="./io_c ${SCALE_FACTOR}"
    CPP_CMD="./io_cpp ${SCALE_FACTOR}"
    GO_CMD="./io_go ${SCALE_FACTOR}"
    RUST_CMD="./io_rust ${SCALE_FACTOR}"
    NIM_CMD="./io_nim ${SCALE_FACTOR}"
    JAVA_CMD="java -server -cp \".${CP_SEP}${GSON_JAR}${CP_SEP}${COMMONS_CSV_JAR}\" io ${SCALE_FACTOR}"
    JULIA_CMD="julia --project=. --optimize=3 --check-bounds=no io.jl ${SCALE_FACTOR}"
fi

# for debug, show what commands will be executed
echo "I/O operations to be benchmarked (scale factor ${SCALE_FACTOR}):"
echo "  C: $C_CMD"
echo "  C++: $CPP_CMD"
echo "  Go: $GO_CMD"
echo "  Java: java io ${SCALE_FACTOR}"
echo "  Julia: julia io.jl ${SCALE_FACTOR}"
echo "  Nim: $NIM_CMD"
echo "  Python: $PYTHON_CMD io.py ${SCALE_FACTOR}"
echo "  Rust: $RUST_CMD"
echo ""

echo "Starting comprehensive I/O performance benchmark..."
echo ""

hyperfine -N --warmup 8 --runs 10 --ignore-failure \
  --command-name "C I/O Benchmark" "$C_CMD" \
  --command-name "C++ I/O Benchmark" "$CPP_CMD" \
  --command-name "Go I/O Benchmark" "$GO_CMD" \
  --command-name "Java I/O Benchmark" "$JAVA_CMD" \
  --command-name "Julia I/O Benchmark" "$JULIA_CMD" \
  --command-name "Nim I/O Benchmark" "$NIM_CMD" \
  --command-name "Python I/O Benchmark" "$PYTHON_CMD io.py ${SCALE_FACTOR}" \
  --command-name "Rust I/O Benchmark" "$RUST_CMD"

echo ""
echo "I/O Performance Benchmark Complete!"
echo "Each language was tested across 3 I/O domains and 7 specific tasks:"
echo "   • File Processing (Sequential Read, Random Access, Memory-Mapped)"
echo "   • CSV Manipulation (Read & Process, Write)"
echo "   • JSON Parsing (DOM Read, Stream Read, Write)"

echo ""
echo "Cleaning up compiled files..."

# windows-specific cleanup to handle file locking issues
if [ "$IS_WINDOWS" = true ]; then
    sleep 1  # give windows time to release file handles
    cmd //c "del io_c.exe io_cpp.exe io_go.exe io_nim.exe io_rust.exe io*.class *.pdb 2>nul"
    # fallback to rm if cmd fails
    rm -f io_c.exe io_cpp.exe io_go.exe io_nim.exe io_rust.exe io*.class *.pdb 2>/dev/null
else
    rm -f io_c io_cpp io_go io_nim io_rust io*.class
fi

# cleanup generated data and libraries
echo "Cleaning up generated files..."
rm -rf data
rm -rf libs
rm -f Cargo.toml Cargo.lock
rm -rf target

echo "All done! Thanks for running this comprehensive I/O benchmark!"