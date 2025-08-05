import sys
import time
import random
import threading
import gc
from concurrent.futures import ThreadPoolExecutor
import array

# simple arena allocator class
class Arena:
    def __init__(self, size):
        self.buffer = bytearray(size)
        self.used = 0
    
    def allocate(self, size):
        # align to 8 bytes
        size = (size + 7) & ~7
        
        if self.used + size > len(self.buffer):
            return None
        
        start = self.used
        self.used += size
        return memoryview(self.buffer[start:start + size])
    
    def reset(self):
        self.used = 0
    
    def capacity(self):
        return len(self.buffer)
    
    def usage(self):
        return self.used

# allocation patterns test - sequential, random, producer-consumer
def allocation_patterns_test(iterations):
    start = time.perf_counter()
    
    # sequential allocation pattern
    ptrs = []
    for i in range(iterations):
        size = 64 + (i % 256)
        ptrs.append(bytearray(size))
    
    ptrs.clear()
    gc.collect()
    
    # random allocation pattern
    random.seed(42)
    raw_ptrs = []
    
    for i in range(iterations):
        size = 32 + random.randint(0, 511)
        raw_ptrs.append(bytearray(size))
    
    # random deallocation (shuffle and clear)
    random.shuffle(raw_ptrs)
    raw_ptrs.clear()
    gc.collect()
    
    end = time.perf_counter()
    _ = iterations  # prevent optimization
    return (end - start) * 1000

# worker function for gc stress test
def gc_stress_worker(thread_id, iterations, counter_lock, counter):
    random.seed(42 + thread_id)
    
    for i in range(iterations):
        size = 16 + random.randint(0, 1023)
        data = bytearray(size)
        
        # simulate work
        for j in range(len(data)):
            data[j] = i & 0xFF
        
        # calculate sum
        total = 0
        for j in range(0, size, 8):
            total += data[j]
        _ = total  # prevent optimization
        
        with counter_lock:
            counter[0] += 1

# gc stress testing with multiple threads
def gc_stress_test(num_threads, iterations_per_thread):
    start = time.perf_counter()
    
    counter = [0]
    counter_lock = threading.Lock()
    
    with ThreadPoolExecutor(max_workers=num_threads) as executor:
        futures = []
        for i in range(num_threads):
            future = executor.submit(gc_stress_worker, i, iterations_per_thread, counter_lock, counter)
            futures.append(future)
        
        # wait for all threads to complete
        for future in futures:
            future.result()
    
    result = counter[0]
    _ = result  # prevent optimization
    
    end = time.perf_counter()
    return (end - start) * 1000

# cache locality and fragmentation test
def cache_locality_test(iterations):
    start = time.perf_counter()
    
    # allocate small and large objects interleaved
    small_ptrs = []
    large_ptrs = []
    
    random.seed(42)
    
    # interleaved allocation pattern
    for i in range(iterations):
        small_size = 16 + random.randint(0, 63)
        large_size = 1024 + random.randint(0, 4095)
        
        small_array = bytearray(small_size)
        large_array = bytearray(large_size)
        
        # access pattern to test spatial locality
        for j in range(len(small_array)):
            small_array[j] = i & 0xFF
        for j in range(min(1024, len(large_array))):
            large_array[j] = (i + 1) & 0xFF
        
        small_ptrs.append(small_array)
        large_ptrs.append(large_array)
    
    # random access pattern to stress cache
    for i in range(iterations // 2):
        idx1 = random.randint(0, iterations - 1)
        idx2 = random.randint(0, iterations - 1)
        
        if idx1 < len(small_ptrs):
            small_array = small_ptrs[idx1]
            total = 0
            for j in range(min(16, len(small_array))):
                total += small_array[j]
            _ = total
        
        if idx2 < len(large_ptrs):
            large_array = large_ptrs[idx2]
            total = 0
            for j in range(0, min(1024, len(large_array)), 64):
                total += large_array[j]
            _ = total
    
    end = time.perf_counter()
    return (end - start) * 1000

# memory pool performance test
def memory_pool_test(iterations):
    start = time.perf_counter()
    
    # test standard allocation
    std_ptrs = []
    for i in range(iterations):
        data = bytearray(128)
        for j in range(len(data)):
            data[j] = i & 0xFF
        std_ptrs.append(data)
    
    std_ptrs.clear()
    gc.collect()
    
    # test arena allocation
    arena = Arena(iterations * 128 + 1024)
    arena_ptrs = []
    
    for i in range(iterations):
        ptr = arena.allocate(128)
        if ptr is not None:
            for j in range(len(ptr)):
                ptr[j] = i & 0xFF
            arena_ptrs.append(ptr)
    
    # batch deallocation
    arena.reset()
    
    # test batch allocation
    for batch in range(10):
        for i in range(iterations // 10):
            ptr = arena.allocate(128)
            if ptr is not None:
                for j in range(len(ptr)):
                    ptr[j] = i & 0xFF
        arena.reset()
    
    end = time.perf_counter()
    return (end - start) * 1000

# memory intensive workloads test
def memory_intensive_test(large_size_mb):
    start = time.perf_counter()
    
    size = large_size_mb * 1024 * 1024
    
    # large object allocation
    large_array1 = bytearray(size)
    large_array2 = bytearray(size)
    
    # memory bandwidth test - sequential write
    for i in range(0, size, 4096):
        large_array1[i] = i & 0xFF
    
    # memory copy operations
    large_array2[:] = large_array1
    
    # memory bandwidth test - sequential read
    total = 0
    for i in range(0, size, 4096):
        total += large_array2[i]
    _ = total
    
    # memory access pattern test
    random.seed(42)
    for i in range(10000):
        offset = random.randint(0, size - 64)
        val = large_array1[offset]
        large_array2[offset] = (val + 1) & 0xFF
    
    end = time.perf_counter()
    return (end - start) * 1000

def main():
    scale_factor = 1
    
    if len(sys.argv) > 1:
        try:
            scale_factor = int(sys.argv[1])
            if scale_factor <= 0:
                scale_factor = 1
        except ValueError:
            print("Invalid scale factor. Using default 1.", file=sys.stderr)
            scale_factor = 1
    
    total_time = 0.0
    
    total_time += allocation_patterns_test(10000 * scale_factor)
    total_time += gc_stress_test(4, 2500 * scale_factor)
    total_time += cache_locality_test(5000 * scale_factor)
    total_time += memory_pool_test(8000 * scale_factor)
    total_time += memory_intensive_test(100 * scale_factor)
    
    print(f"{total_time:.3f}")

if __name__ == "__main__":
    main()