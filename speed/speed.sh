#!/bin/bash

# Comprehensive Speed Benchmark Suite
# Multi-domain performance testing across programming languages

SCALE_FACTOR=3 # this controls the intensity of all benchmark operations

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

# parse command line arguments
if [ $# -gt 0 ]; then
    SCALE_FACTOR=$1
    if ! [[ "$SCALE_FACTOR" =~ ^[1-5]$ ]]; then
        echo "Error: Scale factor must be between 1 and 5"
        echo "Usage: $0 [scale_factor]"
        exit 1
    fi
fi

echo "    Comprehensive Speed Benchmark Suite"
echo ""
echo "Multi-domain performance testing across multiple programming languages"
echo "Testing computational, I/O intensive, and memory management operations"
echo "Scale factor: $SCALE_FACTOR (1=light, 5=intensive)"
echo ""

# check if required subdirectories exist
echo "Validating benchmark environment..."
if [ ! -d "io" ]; then
    echo "Error: 'io' directory not found. Please run this script from the 'speed' directory."
    exit 1
fi
if [ ! -d "mathematical" ]; then
    echo "Error: 'mathematical' directory not found. Please run this script from the 'speed' directory."
    exit 1
fi
if [ ! -d "memory" ]; then
    echo "Error: 'memory' directory not found. Please run this script from the 'speed' directory."
    exit 1
fi

if [ ! -f "io/io.sh" ]; then
    echo "Error: 'io/io.sh' script not found."
    exit 1
fi
if [ ! -f "mathematical/mathematical.sh" ]; then
    echo "Error: 'mathematical/mathematical.sh' script not found."
    exit 1
fi
if [ ! -f "memory/memory.sh" ]; then
    echo "Error: 'memory/memory.sh' script not found."
    exit 1
fi

# check if all required tools are installed
echo "Checking if all required tools are installed"
TOOLS=("$PYTHON_CMD" "javac" "java" "gcc" "g++" "go" "rustc" "cargo" "julia" "nim" "hyperfine" "curl")
all_tools_found=true
for tool in "${TOOLS[@]}"; do
  if ! command -v $tool &> /dev/null; then
    echo "Error: Command not found -> $tool. Please install it first."
    all_tools_found=false
  fi
done

if [ "$all_tools_found" = false ]; then
    echo "Stopping benchmark because some tools are missing."
    echo "Please install all required tools and try again."
    exit 1
fi

# check for clang as alternative compiler
CLANG_AVAILABLE=false
if command -v clang &> /dev/null && command -v clang++ &> /dev/null; then
    CLANG_AVAILABLE=true
    echo "Clang detected - will use for enhanced optimizations"
fi

echo "All tools found. Environment validated successfully."
echo ""

# create results directory for storing individual benchmark results
RESULTS_DIR="benchmark_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo "Starting Comprehensive Speed Benchmark Suite..."
echo "Results will be saved to: $RESULTS_DIR"
echo ""

# execute mathematical benchmark
echo "Phase 1: Mathematical Performance Benchmark"
echo ""
echo "Testing: Matrix Operations, Number Theory, Statistical Computing,"
echo "         Signal Processing, Data Structures"
echo ""

cd mathematical
if [ "$IS_WINDOWS" = true ]; then
    # modify scale factor in the script temporarily
    sed -i "s/SCALE_FACTOR=5/SCALE_FACTOR=$SCALE_FACTOR/" mathematical.sh
    ./mathematical.sh > "../$RESULTS_DIR/mathematical_results.txt" 2>&1
    MATH_EXIT_CODE=$?
    # restore original scale factor
    sed -i "s/SCALE_FACTOR=$SCALE_FACTOR/SCALE_FACTOR=5/" mathematical.sh
else
    # unix-like systems can use environment variables more easily
    SCALE_FACTOR=$SCALE_FACTOR ./mathematical.sh > "../$RESULTS_DIR/mathematical_results.txt" 2>&1
    MATH_EXIT_CODE=$?
fi
cd ..

if [ $MATH_EXIT_CODE -eq 0 ]; then
    echo "Mathematical benchmark completed successfully"
else
    echo "Mathematical benchmark encountered issues (exit code: $MATH_EXIT_CODE)"
fi
echo ""

# execute i/o benchmark  
echo "Phase 2: I/O Performance Benchmark"
echo ""
echo "Testing: File Processing, CSV Manipulation, JSON Parsing"
echo ""

cd io
if [ "$IS_WINDOWS" = true ]; then
    # modify scale factor in the script temporarily
    sed -i "s/SCALE_FACTOR=1/SCALE_FACTOR=$SCALE_FACTOR/" io.sh
    ./io.sh > "../$RESULTS_DIR/io_results.txt" 2>&1
    IO_EXIT_CODE=$?
    # restore original scale factor
    sed -i "s/SCALE_FACTOR=$SCALE_FACTOR/SCALE_FACTOR=1/" io.sh
else
    SCALE_FACTOR=$SCALE_FACTOR ./io.sh > "../$RESULTS_DIR/io_results.txt" 2>&1
    IO_EXIT_CODE=$?
fi
cd ..

if [ $IO_EXIT_CODE -eq 0 ]; then
    echo "I/O benchmark completed successfully"
else
    echo "I/O benchmark encountered issues (exit code: $IO_EXIT_CODE)"
fi
echo ""

# execute memory management benchmark
echo "Phase 3: Memory Management Performance Benchmark"
echo ""
echo "Testing: Allocation Patterns, GC Stress Testing, Cache Locality,"
echo "         Memory Pool Performance, Memory Intensive Workloads"
echo ""

cd memory
if [ "$IS_WINDOWS" = true ]; then
    # modify scale factor in the script temporarily
    sed -i "s/SCALE_FACTOR=1/SCALE_FACTOR=$SCALE_FACTOR/" memory.sh
    ./memory.sh > "../$RESULTS_DIR/memory_results.txt" 2>&1
    MEMORY_EXIT_CODE=$?
    # restore original scale factor
    sed -i "s/SCALE_FACTOR=$SCALE_FACTOR/SCALE_FACTOR=1/" memory.sh
else
    SCALE_FACTOR=$SCALE_FACTOR ./memory.sh > "../$RESULTS_DIR/memory_results.txt" 2>&1
    MEMORY_EXIT_CODE=$?
fi
cd ..

if [ $MEMORY_EXIT_CODE -eq 0 ]; then
    echo "Memory management benchmark completed successfully"
else
    echo "Memory management benchmark encountered issues (exit code: $MEMORY_EXIT_CODE)"
fi
echo ""

# analyze and present results
echo "Comprehensive Speed Benchmark Results Summary"
echo ""

if [ $MATH_EXIT_CODE -eq 0 ]; then
    echo "Mathematical Performance Results:"
    echo ""
    # extract the summary from mathematical results
    grep -A 20 "Summary" "$RESULTS_DIR/mathematical_results.txt" | head -n 15
    echo ""
else
    echo "Mathematical Performance: FAILED"
    echo ""
fi

if [ $IO_EXIT_CODE -eq 0 ]; then
    echo "I/O Performance Results:"
    echo ""
    # extract the summary from io results
    grep -A 20 "Summary" "$RESULTS_DIR/io_results.txt" | head -n 15
    echo ""
else
    echo "I/O Performance: FAILED"
    echo ""
fi

if [ $MEMORY_EXIT_CODE -eq 0 ]; then
    echo "Memory Management Performance Results:"
    echo ""
    # extract the summary from memory results
    grep -A 20 "Summary" "$RESULTS_DIR/memory_results.txt" | head -n 15
    echo ""
else
    echo "Memory Management Performance: FAILED"
    echo ""
fi

# overall analysis
echo "Overall Performance Analysis:"
echo "----------------------------"

COMPLETED_BENCHMARKS=0
[ $MATH_EXIT_CODE -eq 0 ] && ((COMPLETED_BENCHMARKS++))
[ $IO_EXIT_CODE -eq 0 ] && ((COMPLETED_BENCHMARKS++))
[ $MEMORY_EXIT_CODE -eq 0 ] && ((COMPLETED_BENCHMARKS++))

if [ $COMPLETED_BENCHMARKS -eq 3 ]; then
    echo "All three benchmark domains completed successfully"
    echo "Complete performance profile available for all tested languages"
    
    # extract fastest language from each benchmark
    MATH_FASTEST=$(grep "ran$" "$RESULTS_DIR/mathematical_results.txt" | head -n 1 | awk '{print $1}' 2>/dev/null)
    IO_FASTEST=$(grep "ran$" "$RESULTS_DIR/io_results.txt" | head -n 1 | awk '{print $1}' 2>/dev/null)
    MEMORY_FASTEST=$(grep "ran$" "$RESULTS_DIR/memory_results.txt" | head -n 1 | awk '{print $1}' 2>/dev/null)
    
    if [ ! -z "$MATH_FASTEST" ] && [ ! -z "$IO_FASTEST" ] && [ ! -z "$MEMORY_FASTEST" ]; then
        echo "Fastest in Mathematical: $MATH_FASTEST"
        echo "Fastest in I/O: $IO_FASTEST"
        echo "Fastest in Memory Management: $MEMORY_FASTEST"
        
        if [ "$MATH_FASTEST" = "$IO_FASTEST" ] && [ "$MATH_FASTEST" = "$MEMORY_FASTEST" ]; then
            echo "Overall Speed Champion: $MATH_FASTEST (fastest across all domains)"
        else
            echo "No single language dominates all performance domains"
        fi
    fi
elif [ $COMPLETED_BENCHMARKS -eq 2 ]; then
    echo "Two out of three benchmark domains completed successfully"
    echo "Partial performance profile available"
elif [ $COMPLETED_BENCHMARKS -eq 1 ]; then
    echo "Only one benchmark domain completed successfully"
    echo "Limited performance profile available"
else
    echo "All benchmarks failed - please check system configuration"
fi

echo ""
echo "Detailed results saved to: $RESULTS_DIR/"
echo "  - mathematical_results.txt: Complete mathematical benchmark output"
echo "  - io_results.txt: Complete I/O benchmark output"
echo "  - memory_results.txt: Complete memory management benchmark output"
echo ""

# cleanup summary
echo "Benchmark Environment Summary:"
echo "-----------------------------"
echo "• Operating System: $(if [ "$IS_WINDOWS" = true ]; then echo "Windows/MINGW64"; else echo "Unix-like"; fi)"
echo "• Clang Available: $(if [ "$CLANG_AVAILABLE" = true ]; then echo "Yes"; else echo "No"; fi)"
echo "• Scale Factor: $SCALE_FACTOR"
echo "• Languages Tested: C, C++, Go, Java, Julia, Nim, Python, Rust"
echo "• Performance Domains: 3 (Mathematical + I/O + Memory Management)"
echo "• Total Operations Tested: 17+ (5 mathematical + 7 I/O + 5 memory management)"
echo ""

# final status
if [ $COMPLETED_BENCHMARKS -eq 3 ]; then
    echo "Comprehensive Speed Benchmark Suite completed successfully!"
    echo "All languages tested across computational, I/O, and memory management operations."
    echo "Use the results to make informed decisions about language selection"
    echo "for your performance-critical applications."
    exit 0
else
    echo "Comprehensive Speed Benchmark Suite completed with issues."
    echo "Completed benchmarks: $COMPLETED_BENCHMARKS/3"
    echo "Check the detailed logs in $RESULTS_DIR/ for troubleshooting."
    exit 1
fi