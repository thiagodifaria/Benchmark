package main

import (
	"fmt"
	"math/rand"
	"os"
	"runtime"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"
)

// simple arena allocator
type Arena struct {
	buffer []byte
	used   int
}

func NewArena(size int) *Arena {
	return &Arena{
		buffer: make([]byte, size),
		used:   0,
	}
}

func (a *Arena) Allocate(size int) unsafe.Pointer {
	// align to 8 bytes
	size = (size + 7) &^ 7
	
	if a.used+size > len(a.buffer) {
		return nil
	}
	
	ptr := unsafe.Pointer(&a.buffer[a.used])
	a.used += size
	return ptr
}

func (a *Arena) Reset() {
	a.used = 0
}

// allocation patterns test - sequential, random, producer-consumer
func allocationPatternsTest(iterations int) float64 {
	start := time.Now()
	
	// sequential allocation pattern
	ptrs := make([][]byte, iterations)
	for i := 0; i < iterations; i++ {
		size := 64 + (i % 256)
		ptrs[i] = make([]byte, size)
	}
	
	// clear slices (let GC handle it)
	ptrs = nil
	runtime.GC()
	
	// random allocation pattern with manual memory management
	rand.Seed(42)
	rawPtrs := make([]unsafe.Pointer, iterations)
	sizes := make([]int, iterations)
	
	for i := 0; i < iterations; i++ {
		size := 32 + rand.Intn(512)
		// simulate manual allocation
		ptr := make([]byte, size)
		rawPtrs[i] = unsafe.Pointer(&ptr[0])
		sizes[i] = size
	}
	
	// simulate random deallocation by shuffling and accessing
	for i := range rawPtrs {
		j := rand.Intn(i + 1)
		rawPtrs[i], rawPtrs[j] = rawPtrs[j], rawPtrs[i]
		sizes[i], sizes[j] = sizes[j], sizes[i]
	}
	
	// clear references
	rawPtrs = nil
	sizes = nil
	runtime.GC()
	
	duration := time.Since(start)
	_ = iterations // prevent optimization
	return float64(duration.Nanoseconds()) / 1000000.0
}

// worker function for gc stress test
func gcStressWorker(threadID int, iterations int, counter *int64, wg *sync.WaitGroup) {
	defer wg.Done()
	
	rand.Seed(int64(42 + threadID))
	
	for i := 0; i < iterations; i++ {
		size := 16 + rand.Intn(1024)
		data := make([]byte, size)
		
		// simulate work
		for j := range data {
			data[j] = byte(i & 0xFF)
		}
		
		var sum byte
		for j := 0; j < size; j += 8 {
			sum += data[j]
		}
		_ = sum // prevent optimization
		
		atomic.AddInt64(counter, 1)
	}
}

// gc stress testing with multiple threads
func gcStressTest(numThreads int, iterationsPerThread int) float64 {
	start := time.Now()
	
	var counter int64
	var wg sync.WaitGroup
	
	for i := 0; i < numThreads; i++ {
		wg.Add(1)
		go gcStressWorker(i, iterationsPerThread, &counter, &wg)
	}
	
	wg.Wait()
	
	result := atomic.LoadInt64(&counter)
	_ = result // prevent optimization
	
	duration := time.Since(start)
	return float64(duration.Nanoseconds()) / 1000000.0
}

// cache locality and fragmentation test
func cacheLocalityTest(iterations int) float64 {
	start := time.Now()
	
	// allocate small and large objects interleaved
	smallPtrs := make([][]byte, iterations)
	largePtrs := make([][]byte, iterations)
	
	rand.Seed(42)
	
	// interleaved allocation pattern
	for i := 0; i < iterations; i++ {
		smallSize := 16 + rand.Intn(64)
		largeSize := 1024 + rand.Intn(4096)
		
		smallPtrs[i] = make([]byte, smallSize)
		largePtrs[i] = make([]byte, largeSize)
		
		// access pattern to test spatial locality
		for j := range smallPtrs[i] {
			smallPtrs[i][j] = byte(i & 0xFF)
		}
		for j := 0; j < 1024 && j < len(largePtrs[i]); j++ {
			largePtrs[i][j] = byte((i + 1) & 0xFF)
		}
	}
	
	// random access pattern to stress cache
	for i := 0; i < iterations/2; i++ {
		idx1 := rand.Intn(iterations)
		idx2 := rand.Intn(iterations)
		
		if smallPtrs[idx1] != nil {
			var sum byte
			for j := 0; j < 16 && j < len(smallPtrs[idx1]); j++ {
				sum += smallPtrs[idx1][j]
			}
			_ = sum
		}
		
		if largePtrs[idx2] != nil {
			var sum byte
			for j := 0; j < 1024 && j < len(largePtrs[idx2]); j += 64 {
				sum += largePtrs[idx2][j]
			}
			_ = sum
		}
	}
	
	duration := time.Since(start)
	return float64(duration.Nanoseconds()) / 1000000.0
}

// memory pool performance test
func memoryPoolTest(iterations int) float64 {
	start := time.Now()
	
	// test standard allocation
	stdPtrs := make([][]byte, iterations)
	for i := 0; i < iterations; i++ {
		stdPtrs[i] = make([]byte, 128)
		for j := range stdPtrs[i] {
			stdPtrs[i][j] = byte(i & 0xFF)
		}
	}
	stdPtrs = nil
	runtime.GC()
	
	// test arena allocation
	arena := NewArena(iterations*128 + 1024)
	arenaPtrs := make([]unsafe.Pointer, iterations)
	
	for i := 0; i < iterations; i++ {
		ptr := arena.Allocate(128)
		if ptr != nil {
			// simulate memory usage
			slice := (*[128]byte)(ptr)
			for j := 0; j < 128; j++ {
				slice[j] = byte(i & 0xFF)
			}
			arenaPtrs[i] = ptr
		}
	}
	
	// batch deallocation
	arena.Reset()
	
	// test batch allocation
	for batch := 0; batch < 10; batch++ {
		for i := 0; i < iterations/10; i++ {
			ptr := arena.Allocate(128)
			if ptr != nil {
				slice := (*[128]byte)(ptr)
				for j := 0; j < 128; j++ {
					slice[j] = byte(i & 0xFF)
				}
			}
		}
		arena.Reset()
	}
	
	duration := time.Since(start)
	return float64(duration.Nanoseconds()) / 1000000.0
}

// memory intensive workloads test
func memoryIntensiveTest(largeSizeMB int) float64 {
	start := time.Now()
	
	size := largeSizeMB * 1024 * 1024
	
	// large object allocation
	largeArray1 := make([]byte, size)
	largeArray2 := make([]byte, size)
	
	// memory bandwidth test - sequential write
	for i := 0; i < size; i += 4096 {
		largeArray1[i] = byte(i & 0xFF)
	}
	
	// memory copy operations
	copy(largeArray2, largeArray1)
	
	// memory bandwidth test - sequential read
	var sum int64
	for i := 0; i < size; i += 4096 {
		sum += int64(largeArray2[i])
	}
	_ = sum
	
	// memory access pattern test
	rand.Seed(42)
	for i := 0; i < 10000; i++ {
		offset := rand.Intn(size - 64)
		val := largeArray1[offset]
		largeArray2[offset] = val + 1
	}
	
	duration := time.Since(start)
	return float64(duration.Nanoseconds()) / 1000000.0
}

func main() {
	scaleFactor := 1
	
	if len(os.Args) > 1 {
		if factor, err := strconv.Atoi(os.Args[1]); err == nil && factor > 0 {
			scaleFactor = factor
		} else {
			fmt.Fprintf(os.Stderr, "Invalid scale factor. Using default 1.\n")
		}
	}
	
	totalTime := 0.0
	
	totalTime += allocationPatternsTest(10000 * scaleFactor)
	totalTime += gcStressTest(4, 2500*scaleFactor)
	totalTime += cacheLocalityTest(5000 * scaleFactor)
	totalTime += memoryPoolTest(8000 * scaleFactor)
	totalTime += memoryIntensiveTest(100 * scaleFactor)
	
	fmt.Printf("%.3f\n", totalTime)
}