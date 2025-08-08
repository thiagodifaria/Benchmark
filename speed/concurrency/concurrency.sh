#!/bin/bash

SCALE_FACTOR=1 # this controls the intensity of the concurrency operations

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

# check if all the commands exist
echo "Checking if all required tools are installed"
TOOLS=("$PYTHON_CMD" "javac" "java" "gcc" "g++" "go" "rustc" "cargo" "julia" "nim" "hyperfine" "curl")
all_tools_found=true
for tool in "${TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo "Error: Command not found -> $tool. Please install it first."
    all_tools_found=false
  fi
done

# check for clang as alternative to gcc for better concurrency optimization
CLANG_AVAILABLE=false
if command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
    CLANG_AVAILABLE=true
    echo "Clang detected - will use for better concurrency optimization"
fi

if [ "$all_tools_found" = false ]; then
    echo "Stopping script because some tools are missing."
    exit 1
fi
echo "All tools found. Let's continue."
echo ""

# handle dependencies for different languages
echo "Handling dependencies..."
mkdir -p server configs

# create mock server
echo "Creating mock HTTP server..."
cat > server/server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import time
import threading
from urllib.parse import urlparse

class ConcurrencyTestHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/fast':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Fast response')
            
        elif path == '/slow':
            time.sleep(2)  # simulate slow operation
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Slow response')
            
        elif path == '/large':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            large_data = {'data': 'x' * 10000, 'status': 'ok'}
            self.wfile.write(json.dumps(large_data).encode())
            
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        # suppress log messages
        pass

def start_server(port=8000):
    with socketserver.TCPServer(("", port), ConcurrencyTestHandler) as httpd:
        print(f"Mock server running on port {port}")
        httpd.serve_forever()

if __name__ == "__main__":
    import sys
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    start_server(port)
EOF

# create endpoint configuration
cat > configs/endpoints.json << 'EOF'
{
  "fast": {
    "path": "/fast",
    "latency": 10,
    "description": "Fast endpoint with minimal latency"
  },
  "slow": {
    "path": "/slow", 
    "latency": 2000,
    "description": "Slow endpoint simulating heavy processing"
  },
  "large": {
    "path": "/large",
    "latency": 100,
    "payload_size": 10000,
    "description": "Large payload endpoint"
  }
}
EOF

# create parameters configuration
cat > configs/parameters.json << 'EOF'
{
  "concurrency": {
    "http_requests": 50,
    "producer_consumer_pairs": 4,
    "items_per_thread": 1000,
    "math_threads": 4,
    "math_work_per_thread": 100,
    "file_operations": 20,
    "thread_pool_size": 8,
    "thread_pool_tasks": 500
  },
  "server": {
    "host": "127.0.0.1",
    "port": 8000,
    "timeout": 5000
  }
}
EOF

# python dependencies
echo "Installing Python dependencies..."
$PYTHON_CMD -m pip install aiohttp aiofiles requests --quiet --user 2>/dev/null || true

# rust dependencies - create Cargo.toml
CARGO_TOML="Cargo.toml"
echo "Creating Cargo.toml for Rust dependencies..."
cat > $CARGO_TOML << 'EOF'
[package]
name = "concurrency_bench"
version = "0.1.0"
edition = "2021"

[[bin]]
name = "concurrency_bench"
path = "concurrency.rs"

[dependencies]
tokio = { version = "1.0", features = ["full"] }
reqwest = { version = "0.11", features = ["json"] }
rayon = "1.5"
tempfile = "3.0"
EOF

echo "All dependencies prepared."
echo ""

# start mock server
echo "Starting mock HTTP server..."
$PYTHON_CMD server/server.py 8000 &
SERVER_PID=$!
sleep 2  # give server time to start
echo "Mock server started with PID $SERVER_PID"
echo ""

# this is where we compile everything, with checks after each command
echo "Compiling all languages"

echo "Compiling Java code..."
javac concurrency.java
if [ $? -ne 0 ]; then echo "Java compilation failed. Stopping."; exit 1; fi

# for c, use clang if available for better concurrency optimization, otherwise gcc
echo "Compiling C code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang for better concurrency optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -fopenmp -o "concurrency_c${EXE_EXT}" concurrency.c -lm -lpthread
    else
        clang -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -fopenmp -o "concurrency_c${EXE_EXT}" concurrency.c -lm -lpthread
    fi
else
    echo "Using GCC with enhanced concurrency flags..."
    if [ "$IS_WINDOWS" = true ]; then
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -fopenmp -static -o "concurrency_c${EXE_EXT}" concurrency.c -lm -lpthread
    else
        gcc -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -fopenmp -static -o "concurrency_c${EXE_EXT}" concurrency.c -lm -lpthread
    fi
fi
if [ $? -ne 0 ]; then echo "C compilation failed. Stopping."; exit 1; fi

# for cpp, use clang++ if available for better concurrency optimization
echo "Compiling C++ code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Using Clang++ for better concurrency optimization..."
    if [ "$IS_WINDOWS" = true ]; then
        clang++ -std=c++17 -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -static-libgcc -static-libstdc++ -o "concurrency_cpp${EXE_EXT}" concurrency.cpp -lpthread
    else
        clang++ -std=c++17 -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "concurrency_cpp${EXE_EXT}" concurrency.cpp -lpthread
    fi
else
    echo "Using G++ with enhanced concurrency flags..."
    if [ "$IS_WINDOWS" = true ]; then
        g++ -std=c++17 -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -static-libgcc -static-libstdc++ -o "concurrency_cpp${EXE_EXT}" concurrency.cpp -lpthread
    else
        g++ -std=c++17 -O3 -DNDEBUG -ffast-math -march=native -mtune=native -funroll-loops -flto -static -o "concurrency_cpp${EXE_EXT}" concurrency.cpp -lpthread
    fi
fi
if [ $? -ne 0 ]; then echo "C++ compilation failed. Stopping."; exit 1; fi

echo "Compiling Go code..."
go build -ldflags="-s -w" -gcflags="-B" -o "concurrency_go${EXE_EXT}" concurrency.go
if [ $? -ne 0 ]; then echo "Go compilation failed. Stopping."; exit 1; fi

# julia doesn't need compilation, it's JIT compiled
echo "Julia ready (JIT compiled at runtime)"

# nim with async and threading support
echo "Compiling Nim code..."
if [ "$CLANG_AVAILABLE" = true ]; then
    echo "Nim using Clang backend for better concurrency..."
    nim c -d:release -d:lto --opt:speed --mm:orc --threads:on --cc:clang --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops" --passL:"-flto" -o:"concurrency_nim${EXE_EXT}" concurrency.nim
else
    echo "Nim using GCC backend with concurrency flags..."
    nim c -d:release -d:lto --opt:speed --mm:orc --threads:on --passC:"-O3 -ffast-math -march=native -mtune=native -funroll-loops" --passL:"-flto" -o:"concurrency_nim${EXE_EXT}" concurrency.nim
fi
if [ $? -ne 0 ]; then echo "Nim compilation failed. Stopping."; exit 1; fi

echo "Compiling Rust code with Cargo..."
cargo build --release --quiet
if [ $? -ne 0 ]; then echo "Rust compilation failed. Stopping."; exit 1; fi
cp "target/release/concurrency_bench${EXE_EXT}" "concurrency_rust${EXE_EXT}"

echo "All compilations were successful!"
echo ""

# running the comprehensive concurrency performance test
echo "Running the comprehensive Concurrency performance test!"
echo "Languages: C, C++, Go, Java, Julia, Nim, Python, Rust"
echo "Operations: Parallel HTTP Requests, Producer-Consumer Queue,"
echo "           Parallel Mathematical Work, Async File Processing,"
echo "           Thread Pool Performance"
echo "Scale factor ${SCALE_FACTOR} selected for intensive performance measurement"
echo ""

# Build command array based on OS
if [ "$IS_WINDOWS" = true ]; then
    C_CMD="./concurrency_c.exe ${SCALE_FACTOR}"
    CPP_CMD="./concurrency_cpp.exe ${SCALE_FACTOR}"
    GO_CMD="./concurrency_go.exe ${SCALE_FACTOR}"
    RUST_CMD="./concurrency_rust.exe ${SCALE_FACTOR}"
    NIM_CMD="./concurrency_nim.exe ${SCALE_FACTOR}"
    JAVA_CMD="java -server concurrency ${SCALE_FACTOR}"
    JULIA_CMD="julia --project=. --optimize=3 --check-bounds=no -t auto concurrency.jl ${SCALE_FACTOR}"
else
    C_CMD="./concurrency_c ${SCALE_FACTOR}"
    CPP_CMD="./concurrency_cpp ${SCALE_FACTOR}"
    GO_CMD="./concurrency_go ${SCALE_FACTOR}"
    RUST_CMD="./concurrency_rust ${SCALE_FACTOR}"
    NIM_CMD="./concurrency_nim ${SCALE_FACTOR}"
    JAVA_CMD="java -server concurrency ${SCALE_FACTOR}"
    JULIA_CMD="julia --project=. --optimize=3 --check-bounds=no -t auto concurrency.jl ${SCALE_FACTOR}"
fi

# for debug, show what commands will be executed
echo "Concurrency operations to be benchmarked (scale factor ${SCALE_FACTOR}):"
echo "  C: $C_CMD"
echo "  C++: $CPP_CMD"
echo "  Go: $GO_CMD"
echo "  Java: java concurrency ${SCALE_FACTOR}"
echo "  Julia: julia concurrency.jl ${SCALE_FACTOR}"
echo "  Nim: $NIM_CMD"
echo "  Python: $PYTHON_CMD concurrency.py ${SCALE_FACTOR}"
echo "  Rust: $RUST_CMD"
echo ""

echo "Starting comprehensive concurrency performance benchmark..."
echo ""

hyperfine -N --warmup 5 --runs 8 --ignore-failure \
  --command-name "C Concurrency Benchmark" "$C_CMD" \
  --command-name "C++ Concurrency Benchmark" "$CPP_CMD" \
  --command-name "Go Concurrency Benchmark" "$GO_CMD" \
  --command-name "Java Concurrency Benchmark" "$JAVA_CMD" \
  --command-name "Julia Concurrency Benchmark" "$JULIA_CMD" \
  --command-name "Nim Concurrency Benchmark" "$NIM_CMD" \
  --command-name "Python Concurrency Benchmark" "$PYTHON_CMD concurrency.py ${SCALE_FACTOR}" \
  --command-name "Rust Concurrency Benchmark" "$RUST_CMD"

echo ""
echo "Concurrency Performance Benchmark Complete!"
echo "Each language was tested across 5 concurrency domains:"
echo "   • Parallel HTTP Requests (I/O-bound concurrency)"
echo "   • Producer-Consumer Queue (Threading coordination)"
echo "   • Parallel Mathematical Work (CPU-bound parallelism)"
echo "   • Async File Processing (Mixed workload)"
echo "   • Thread Pool Performance (Resource management)"

echo ""
echo "Stopping mock server..."
kill $SERVER_PID 2>/dev/null || true
sleep 1

echo "Cleaning up compiled files..."

# windows-specific cleanup to handle file locking issues
if [ "$IS_WINDOWS" = true ]; then
    sleep 1  # give windows time to release file handles
    cmd //c "del concurrency_c.exe concurrency_cpp.exe concurrency_go.exe concurrency_nim.exe concurrency_rust.exe concurrency*.class *.pdb 2>nul"
    # fallback to rm if cmd fails
    rm -f concurrency_c.exe concurrency_cpp.exe concurrency_go.exe concurrency_nim.exe concurrency_rust.exe concurrency*.class *.pdb 2>/dev/null
else
    rm -f concurrency_c concurrency_cpp concurrency_go concurrency_nim concurrency_rust concurrency*.class
fi

# cleanup generated files
echo "Cleaning up generated files..."
rm -rf server configs target
rm -f Cargo.toml Cargo.lock

echo "All done! Thanks for running this comprehensive concurrency benchmark!"