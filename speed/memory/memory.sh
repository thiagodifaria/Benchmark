#!/bin/bash

SCALE_FACTOR=1 # this controls the intensity of the memory management operations

# detect if we're running on windows/mingw64
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$MINGW_CHOST" ]]; then
    IS_WINDOWS=true
    EXE_EXT=".exe"
    PYTHON_CMD="python"
    echo "Detected Windows/MINGW64 environment"
else
    IS_WINDOWS=false
    EXE_EXT=""
    PYTHON_CMD="python3"
    echo "Detected Unix-like environment"
fi

# check if all the commands like 'go', 'rustc', and 'hyperfine' exist
echo "Checking if all required tools are installed"
TOOLS=("$PYTHON_CMD" "javac" "java" "gcc" "g++" "go" "rustc" "cargo" "julia" "nim" "hyperfine")
all_tools_found=true
for tool in "${TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo "Error: Command not found -> $tool. Please install it first."
    all_tools_found=false
  fi
done

# check for clang as alternative to gcc for better optimization
CLANG_AVAILABLE=false
if command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
    CLANG_AVAILABLE=true
    echo "Clang detected - will use for better memory management optimization"
fi

if [ "$all_tools_found" = false ]; then
    echo "Stopping script because some tools are missing."
    exit 1
fi
echo "All tools found. Let's continue."
echo ""

# this is where we compile everything, with checks after each command
echo "Compiling all languages"

echo "Compiling Java code..."
javac memory.java
if [ $? -ne 0 ]; then echo "Java compilation failed. Stopping."; exit 1; fi

# for c, use clang if available for better memory management, otherwise gcc with maximum optimization  
echo "Compiling C code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang for better memory management optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -o "memory_c${EXE_EXT}" memory.c -lm
    else
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -o "memory_c${EXE_EXT}" memory.c -lm -lpthread
    fi
else
    echo "Using GCC with enhanced optimization flags..."
    if [ "$IS_WINDOWS" = true ]; then
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "memory_c${EXE_EXT}" memory.c -lm
    else
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "memory_c${EXE_EXT}" memory.c -lm -lpthread
    fi
fi
if [ $? -ne 0 ]; then echo "C compilation failed. Stopping."; exit 1; fi

# for cpp, use clang++ if available for better optimization
echo "Compiling C++ code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang++ for better memory management optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -static-libgcc -static-libstdc++ -o "memory_cpp${EXE_EXT}" memory.cpp
    else
        clang++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "memory_cpp${EXE_EXT}" memory.cpp -lpthread
    fi
else
    echo "Using G++ with enhanced optimization flags..."
    if [ "$IS_WINDOWS" = true ]; then
        g++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -static-libgcc -static-libstdc++ -o "memory_cpp${EXE_EXT}" memory.cpp
    else
        g++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "memory_cpp${EXE_EXT}" memory.cpp -lpthread
    fi
fi
if [ $? -ne 0 ]; then echo "C++ compilation failed. Stopping."; exit 1; fi

echo "Compiling Go code..."
go build -ldflags="-s -w" -gcflags="-B" -o "memory_go${EXE_EXT}" memory.go
if [ $? -ne 0 ]; then echo "Go compilation failed. Stopping."; exit 1; fi

# julia doesn't need compilation, it's JIT compiled
echo "Julia ready (JIT compiled at runtime)"

# nim with optimized flags - use --mm:orc to avoid ARC threading issues
echo "Compiling Nim code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Nim using Clang backend for better optimization..."
    nim c -d:release -d:lto --opt:speed --mm:orc --cc:clang --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops" --passL:"-flto" -o:"memory_nim${EXE_EXT}" memory.nim
else
    echo "Nim using GCC backend with enhanced flags..."
    nim c -d:release -d:lto --opt:speed --mm:orc --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops" --passL:"-flto" -o:"memory_nim${EXE_EXT}" memory.nim
fi
if [ $? -ne 0 ]; then echo "Nim compilation failed. Stopping."; exit 1; fi

echo "Compiling Rust code with Cargo..."
# create a cargo.toml file to handle dependencies
CARGO_TOML="Cargo.toml"
echo "Creating Cargo.toml for Rust dependencies..."
echo '[package]' > $CARGO_TOML
echo 'name = "memory_bench"' >> $CARGO_TOML
echo 'version = "0.1.0"' >> $CARGO_TOML
echo 'edition = "2021"' >> $CARGO_TOML
echo '' >> $CARGO_TOML
echo '[[bin]]' >> $CARGO_TOML
echo 'name = "memory_bench"' >> $CARGO_TOML
echo 'path = "memory.rs"' >> $CARGO_TOML
echo '' >> $CARGO_TOML
echo '[dependencies]' >> $CARGO_TOML
echo 'rand = "0.8"' >> $CARGO_TOML

cargo build --release --quiet
if [ $? -ne 0 ]; then echo "Rust compilation failed. Stopping."; exit 1; fi
cp "target/release/memory_bench${EXE_EXT}" "memory_rust${EXE_EXT}"

echo "All compilations were successful!"
echo ""

# running the comprehensive memory management performance test
echo "Running the comprehensive Memory Management performance test!"
echo "Languages: C, C++, Go, Java, Julia, Nim, Python, Rust"
echo "Operations: Allocation Patterns, GC Stress Testing, Cache Locality,"
echo "           Memory Pool Performance, Memory Intensive Workloads"
echo "Scale factor ${SCALE_FACTOR} selected for intensive performance measurement"
echo ""

# Build command array based on OS
if [ "$IS_WINDOWS" = true ]; then
    C_CMD="./memory_c.exe ${SCALE_FACTOR}"
    CPP_CMD="./memory_cpp.exe ${SCALE_FACTOR}"
    GO_CMD="./memory_go.exe ${SCALE_FACTOR}"
    RUST_CMD="./memory_rust.exe ${SCALE_FACTOR}"
    NIM_CMD="./memory_nim.exe ${SCALE_FACTOR}"
    JAVA_CMD="java -server memory ${SCALE_FACTOR}"
    JULIA_CMD="julia --optimize=3 --check-bounds=no memory.jl ${SCALE_FACTOR}"
else
    C_CMD="./memory_c ${SCALE_FACTOR}"
    CPP_CMD="./memory_cpp ${SCALE_FACTOR}"
    GO_CMD="./memory_go ${SCALE_FACTOR}"
    RUST_CMD="./memory_rust ${SCALE_FACTOR}"
    NIM_CMD="./memory_nim ${SCALE_FACTOR}"
    JAVA_CMD="java -server memory ${SCALE_FACTOR}"
    JULIA_CMD="julia --optimize=3 --check-bounds=no memory.jl ${SCALE_FACTOR}"
fi

# for debug, show what commands will be executed
echo "Memory management operations to be benchmarked (scale factor ${SCALE_FACTOR}):"
echo "  C: $C_CMD"
echo "  C++: $CPP_CMD"
echo "  Go: $GO_CMD"
echo "  Java: java memory ${SCALE_FACTOR}"
echo "  Julia: julia memory.jl ${SCALE_FACTOR}"
echo "  Nim: $NIM_CMD"
echo "  Python: $PYTHON_CMD memory.py ${SCALE_FACTOR}"
echo "  Rust: $RUST_CMD"
echo ""

echo "Starting comprehensive memory management performance benchmark..."
echo ""

hyperfine -N --warmup 5 --runs 8 --ignore-failure \
  --command-name "C Memory Benchmark" "$C_CMD" \
  --command-name "C++ Memory Benchmark" "$CPP_CMD" \
  --command-name "Go Memory Benchmark" "$GO_CMD" \
  --command-name "Java Memory Benchmark" "$JAVA_CMD" \
  --command-name "Julia Memory Benchmark" "$JULIA_CMD" \
  --command-name "Nim Memory Benchmark" "$NIM_CMD" \
  --command-name "Python Memory Benchmark" "$PYTHON_CMD memory.py ${SCALE_FACTOR}" \
  --command-name "Rust Memory Benchmark" "$RUST_CMD"

echo ""
echo "Memory Management Performance Benchmark Complete!"
echo "Each language was tested across 5 memory management domains:"
echo "   • Allocation Patterns (Sequential, Random, Producer-Consumer)"
echo "   • GC Stress Testing (Multi-threaded allocation pressure)" 
echo "   • Cache Locality & Fragmentation (Interleaved small/large objects)"
echo "   • Memory Pool Performance (Arena vs standard allocation)"
echo "   • Memory Intensive Workloads (Large arrays, bandwidth testing)"

echo ""
echo "Cleaning up compiled files..."

# windows-specific cleanup to handle file locking issues
if [ "$IS_WINDOWS" = true ]; then
    sleep 1  # give windows time to release file handles
    cmd //c "del memory_c.exe memory_cpp.exe memory_go.exe memory_nim.exe memory_rust.exe memory*.class *.pdb 2>nul"
    # fallback to rm if cmd fails
    rm -f memory_c.exe memory_cpp.exe memory_go.exe memory_nim.exe memory_rust.exe memory*.class *.pdb 2>/dev/null
else
    rm -f memory_c memory_cpp memory_go memory_nim memory_rust memory*.class
fi

# cleanup generated files
echo "Cleaning up generated files..."
rm -f Cargo.toml Cargo.lock
rm -rf target

echo "All done! Thanks for running this comprehensive memory management benchmark!"