package main

import (
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

// parallel http requests test using goroutines
func parallelHttpTest(numRequests int) float64 {
	start := time.Now()

	var wg sync.WaitGroup
	var successful int32

	for i := 0; i < numRequests; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()

			client := &http.Client{
				Timeout: 5 * time.Second,
			}

			resp, err := client.Get("http://127.0.0.1:8000/fast")
			if err == nil {
				io.Copy(ioutil.Discard, resp.Body)
				resp.Body.Close()
				atomic.AddInt32(&successful, 1)
			}
		}()
	}

	wg.Wait()

	duration := time.Since(start)
	_ = atomic.LoadInt32(&successful) // prevent optimization
	return float64(duration.Nanoseconds()) / 1000000.0
}

// producer-consumer queue test using channels
func producerConsumerTest(numPairs int, itemsPerThread int) float64 {
	start := time.Now()

	// buffered channel acts as our queue
	taskQueue := make(chan int, 1000)
	var processed int32
	var wg sync.WaitGroup

	// create producer goroutines
	for i := 0; i < numPairs; i++ {
		wg.Add(1)
		go func(producerID int) {
			defer wg.Done()
			for j := 0; j < itemsPerThread; j++ {
				taskQueue <- producerID*1000 + j
			}
		}(i)
	}

	// create consumer goroutines
	for i := 0; i < numPairs; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < itemsPerThread; j++ {
				item := <-taskQueue

				// simulate processing
				_ = item * item

				atomic.AddInt32(&processed, 1)
			}
		}()
	}

	wg.Wait()
	close(taskQueue)

	duration := time.Since(start)
	_ = atomic.LoadInt32(&processed) // prevent optimization
	return float64(duration.Nanoseconds()) / 1000000.0
}

// fibonacci computation
func fibonacci(n int) int64 {
	if n <= 1 {
		return int64(n)
	}

	a, b := int64(0), int64(1)
	for i := 2; i <= n; i++ {
		a, b = b, a+b
	}
	return b
}

// parallel mathematical work test
func parallelMathTest(numThreads int, workPerThread int) float64 {
	start := time.Now()

	var wg sync.WaitGroup
	var totalSum int64

	for i := 0; i < numThreads; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			var localSum int64
			for j := 0; j < workPerThread; j++ {
				localSum += fibonacci(35)

				// additional mathematical work
				for k := 0; k < 1000; k++ {
					localSum += int64(k * k)
				}
			}

			atomic.AddInt64(&totalSum, localSum)
		}(i)
	}

	wg.Wait()

	duration := time.Since(start)
	_ = atomic.LoadInt64(&totalSum) // prevent optimization
	return float64(duration.Nanoseconds()) / 1000000.0
}

// async file processing test
func asyncFileTest(numFiles int) float64 {
	start := time.Now()

	tempDir, err := ioutil.TempDir("", "concurrency_test")
	if err != nil {
		return 0.0
	}
	defer os.RemoveAll(tempDir)

	var wg sync.WaitGroup
	var processed int32

	for i := 0; i < numFiles; i++ {
		wg.Add(1)
		go func(fileID int) {
			defer wg.Done()

			filename := filepath.Join(tempDir, fmt.Sprintf("test_%d.dat", fileID))

			// write file
			file, err := os.Create(filename)
			if err != nil {
				return
			}

			for j := 0; j < 1000; j++ {
				fmt.Fprintf(file, "data_%d_%d\n", fileID, j)
			}
			file.Close()

			// read and process file
			content, err := ioutil.ReadFile(filename)
			if err != nil {
				return
			}

			// simulate processing
			lines := 0
			for _, b := range content {
				if b == '\n' {
					lines++
				}
			}

			if lines > 0 {
				atomic.AddInt32(&processed, 1)
			}

			// cleanup
			os.Remove(filename)
		}(i)
	}

	wg.Wait()

	duration := time.Since(start)
	_ = atomic.LoadInt32(&processed) // prevent optimization
	return float64(duration.Nanoseconds()) / 1000000.0
}

// worker pool structure
type WorkerPool struct {
	taskQueue chan func()
	wg        sync.WaitGroup
}

func NewWorkerPool(numWorkers int) *WorkerPool {
	pool := &WorkerPool{
		taskQueue: make(chan func(), 100),
	}

	// start worker goroutines
	for i := 0; i < numWorkers; i++ {
		go func() {
			for task := range pool.taskQueue {
				task()
			}
		}()
	}

	return pool
}

func (p *WorkerPool) Submit(task func()) {
	p.wg.Add(1)
	p.taskQueue <- func() {
		defer p.wg.Done()
		task()
	}
}

func (p *WorkerPool) Wait() {
	p.wg.Wait()
}

func (p *WorkerPool) Close() {
	close(p.taskQueue)
}

// thread pool performance test
func threadPoolTest(poolSize int, totalTasks int) float64 {
	start := time.Now()

	pool := NewWorkerPool(poolSize)
	defer pool.Close()

	var completed int32

	for i := 0; i < totalTasks; i++ {
		taskID := i
		pool.Submit(func() {
			// simulate varied workload
			var work int64
			for j := 0; j < 10000; j++ {
				work += int64(j * j)
			}

			time.Sleep(100 * time.Microsecond)
			atomic.AddInt32(&completed, 1)

			_ = work // prevent optimization
		})
	}

	pool.Wait()

	duration := time.Since(start)
	_ = atomic.LoadInt32(&completed) // prevent optimization
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

	totalTime += parallelHttpTest(50 * scaleFactor)
	totalTime += producerConsumerTest(4, 1000*scaleFactor)
	totalTime += parallelMathTest(4, 100*scaleFactor)
	totalTime += asyncFileTest(20 * scaleFactor)
	totalTime += threadPoolTest(8, 500*scaleFactor)

	fmt.Printf("%.3f\n", totalTime)
}