#!/bin/bash

SCALE_FACTOR=5 # this controls the intensity of the mathematical operations

# detect if we're running on Windows/MINGW64
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

## check if all the commands like 'go', 'rustc', and 'hyperfine' exist

echo "Checking if all required tools are installed"
if [ "$IS_WINDOWS" = true ]; then
    TOOLS=("python" "javac" "gcc" "g++" "go" "rustc" "julia" "nim" "hyperfine")
else
    TOOLS=("python3" "javac" "gcc" "g++" "go" "rustc" "julia" "nim" "hyperfine")
fi
all_tools_found=true

for tool in "${TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo "Error: command not found -> $tool. Please install it first."
    all_tools_found=false
  fi
done

# check for clang as alternative to gcc for better vectorization
CLANG_AVAILABLE=false
if command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
    CLANG_AVAILABLE=true
    echo "Clang detected - will use for better SIMD optimization"
fi

# if a tool is missing, the script should just stop here
if [ "$all_tools_found" = false ]; then
  echo "Stopping script because some tools are missing."
  exit 1
fi

echo "All tools found. Let's continue."
echo ""

# this is where we compile everything, i've added a check after each compile command, if it fails, the script stops

echo "Compiling all languages"

# first for java, javac should create a mathematical.class file.
echo "Compiling Java code..."
javac mathematical.java
if [ $? -ne 0 ]; then echo "Java compilation failed. Stopping."; exit 1; fi

# for c, use clang if available for better auto-vectorization, otherwise gcc with maximum optimization  
echo "Compiling C code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang for better SIMD optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -o "mathematical_c${EXE_EXT}" mathematical.c -lm
    else
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -o "mathematical_c${EXE_EXT}" mathematical.c -lm
    fi
else
    echo "Using GCC with enhanced optimization flags..."
    if [ "$IS_WINDOWS" = true ]; then
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -ftree-vectorize -floop-interchange -floop-strip-mine -floop-block -static -o "mathematical_c${EXE_EXT}" mathematical.c -lm
    else
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -ftree-vectorize -floop-interchange -floop-strip-mine -floop-block -static -o "mathematical_c${EXE_EXT}" mathematical.c -lm
    fi
fi
if [ $? -ne 0 ]; then echo "C compilation failed. Stopping."; exit 1; fi

# for cpp, use clang++ if available for better optimization
echo "Compiling C++ code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang++ for better SIMD optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -static -static-libgcc -static-libstdc++ -o "mathematical_cpp${EXE_EXT}" mathematical.cpp
    else
        clang++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -static -o "mathematical_cpp${EXE_EXT}" mathematical.cpp
    fi
else
    echo "Using G++ with enhanced optimization flags..."
    if [ "$IS_WINDOWS" = true ]; then
        g++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -ftree-vectorize -floop-interchange -floop-strip-mine -floop-block -static -static-libgcc -static-libstdc++ -o "mathematical_cpp${EXE_EXT}" mathematical.cpp
    else
        g++ -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -msse4.2 -mavx -mavx2 -mfma -ftree-vectorize -floop-interchange -floop-strip-mine -floop-block -static -o "mathematical_cpp${EXE_EXT}" mathematical.cpp
    fi
fi

if [ $? -ne 0 ]; then echo "C++ compilation failed. Stopping."; exit 1; fi

# test the C++ executable immediately after compilation
echo "Testing C++ executable..."
if [ "$IS_WINDOWS" = true ]; then
    test_result=$(./mathematical_cpp.exe 1 2>&1)
    test_exit_code=$?
else
    test_result=$(./mathematical_cpp 1 2>&1)
    test_exit_code=$?
fi

echo "C++ test result: $test_result ms (exit code: $test_exit_code)"
if [ $test_exit_code -ne 0 ]; then 
    echo "C++ executable test failed. Output: $test_result"
    echo "Stopping."; 
    exit 1; 
fi

# i think Go is pretty straightforward, 'go build' should do everything
echo "Compiling Go code..."
go build -ldflags="-s -w" -gcflags="-B" -o "mathematical_go${EXE_EXT}" mathematical.go
if [ $? -ne 0 ]; then echo "Go compilation failed. Stopping."; exit 1; fi

# julia doesn't need compilation, it's JIT compiled
echo "Julia ready (JIT compiled at runtime)"

# nim with optimized flags - use --mm:none to avoid ARC threading issues
echo "Compiling Nim code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Nim using Clang backend for better optimization..."
    nim c -d:release -d:lto --opt:speed --mm:none --cc:clang --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops -msse4.2 -mavx -mavx2 -mfma" --passL:"-flto" -o:"mathematical_nim${EXE_EXT}" mathematical.nim
else
    echo "Nim using GCC backend with enhanced flags..."
    nim c -d:release -d:lto --opt:speed --mm:none --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops -msse4.2 -mavx -mavx2 -mfma -ftree-vectorize" --passL:"-flto" -o:"mathematical_nim${EXE_EXT}" mathematical.nim
fi
if [ $? -ne 0 ]; then echo "Nim compilation failed. Stopping."; exit 1; fi

# and finally rust, optimization flags
echo "Compiling Rust code..."
rustc -C opt-level=3 -C target-cpu=native -C lto=fat -C codegen-units=1 -o "mathematical_rust${EXE_EXT}" mathematical.rs
# one last check for rust...
if [ $? -ne 0 ]; then echo "Rust compilation failed. Stopping."; exit 1; fi

# python still doesn't need compiling
echo "All compilations were successful!"
echo ""

# if we got here, it means everything compiled fine

echo "Running the comprehensive mathematical performance test!"
echo "Languages: C, C++, Go, Java, Julia, Nim, Python, Rust"
echo "Operations: Matrix, Number Theory, Statistical Computing, Signal Processing, Data Structures"
echo "Scale factor ${SCALE_FACTOR} selected for intensive performance measurement"
echo ""

# Build command array based on OS
if [ "$IS_WINDOWS" = true ]; then
    C_CMD="./mathematical_c.exe ${SCALE_FACTOR}"
    CPP_CMD="./mathematical_cpp.exe ${SCALE_FACTOR}"
    GO_CMD="./mathematical_go.exe ${SCALE_FACTOR}"
    RUST_CMD="./mathematical_rust.exe ${SCALE_FACTOR}"
    NIM_CMD="./mathematical_nim.exe ${SCALE_FACTOR}"
    JAVA_CMD="java -server mathematical ${SCALE_FACTOR}"
    JULIA_CMD="julia --optimize=3 --check-bounds=no mathematical.jl ${SCALE_FACTOR}"
else
    C_CMD="./mathematical_c ${SCALE_FACTOR}"
    CPP_CMD="./mathematical_cpp ${SCALE_FACTOR}"
    GO_CMD="./mathematical_go ${SCALE_FACTOR}"
    RUST_CMD="./mathematical_rust ${SCALE_FACTOR}"
    NIM_CMD="./mathematical_nim ${SCALE_FACTOR}"
    JAVA_CMD="java -server mathematical ${SCALE_FACTOR}"
    JULIA_CMD="julia --optimize=3 --check-bounds=no mathematical.jl ${SCALE_FACTOR}"
fi

# for debug, that show what commands will be executed
echo "Mathematical operations to be benchmarked (scale factor ${SCALE_FACTOR}):"
echo "  C: $C_CMD"
echo "  C++: $CPP_CMD"
echo "  Go: $GO_CMD"
echo "  Java: java mathematical ${SCALE_FACTOR}"
echo "  Julia: julia mathematical.jl ${SCALE_FACTOR}"
echo "  Nim: $NIM_CMD"
echo "  Python: $PYTHON_CMD mathematical.py ${SCALE_FACTOR}"
echo "  Rust: $RUST_CMD"
echo ""

# we're using hyperfine with shell=none to avoid Windows timing issues
echo "Starting comprehensive mathematical performance benchmark..."
echo ""

hyperfine -N --warmup 8 --runs 10 --ignore-failure \
  --command-name "C Benchmark" "$C_CMD" \
  --command-name "C++ Benchmark" "$CPP_CMD" \
  --command-name "Go Benchmark" "$GO_CMD" \
  --command-name "Java Benchmark" "$JAVA_CMD" \
  --command-name "Julia Benchmark" "$JULIA_CMD" \
  --command-name "Nim Benchmark" "$NIM_CMD" \
  --command-name "Python Benchmark" "$PYTHON_CMD mathematical.py ${SCALE_FACTOR}" \
  --command-name "Rust Benchmark" "$RUST_CMD"

echo ""
echo "Mathematical Performance Benchmark Complete!"
echo "Each language was tested across 5 mathematical domains:"
echo "   • Matrix Operations (blocked multiplication, transpose)"  
echo "   • Number Theory (prime sieve, factorization, twin primes)"
echo "   • Statistical Computing (Monte Carlo, normal distribution)" 
echo "   • Signal Processing (FFT, convolution, round-trip accuracy)"
echo "   • Data Structures (multiple sorts, binary search, heap ops)"

echo ""
echo "Cleaning up compiled files..."

# windows-specific cleanup to handle file locking issues
if [ "$IS_WINDOWS" = true ]; then
    sleep 1  # give windows time to release file handles
    cmd //c "del mathematical_c.exe mathematical_cpp.exe mathematical_go.exe mathematical_nim.exe mathematical_rust.exe mathematical*.class *.pdb 2>nul"
    # fallback to rm if cmd fails
    rm -f mathematical_c.exe mathematical_cpp.exe mathematical_go.exe mathematical_nim.exe mathematical_rust.exe mathematical*.class *.pdb 2>/dev/null
else
    rm -f mathematical_c mathematical_cpp mathematical_go mathematical_nim mathematical_rust mathematical*.class
fi

echo "All done! Thanks for running this comprehensive mathematical benchmark!"