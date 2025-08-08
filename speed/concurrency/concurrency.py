import sys
import time
import asyncio
import aiohttp
import aiofiles
import threading
import queue
import tempfile
import os
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
from multiprocessing import cpu_count
import requests
from pathlib import Path

# parallel http requests test using async/await
async def parallel_http_test(num_requests):
    start = time.perf_counter()
    
    async def make_request(session):
        try:
            async with session.get('http://127.0.0.1:8000/fast', timeout=5) as response:
                await response.text()
                return True
        except:
            return False
    
    async with aiohttp.ClientSession() as session:
        tasks = [make_request(session) for _ in range(num_requests)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
    
    successful = sum(1 for r in results if r is True)
    end = time.perf_counter()
    
    _ = successful  # prevent optimization
    return (end - start) * 1000

# producer-consumer queue test using threading
def producer_consumer_test(num_pairs, items_per_thread):
    start = time.perf_counter()
    
    task_queue = queue.Queue(maxsize=1000)
    processed = threading.local()
    processed.count = 0
    
    def producer(producer_id):
        for i in range(items_per_thread):
            task_queue.put(producer_id * 1000 + i)
    
    def consumer():
        local_count = 0
        for _ in range(items_per_thread):
            item = task_queue.get()
            
            # simulate processing
            dummy = item * item
            
            local_count += 1
            task_queue.task_done()
        
        with threading.Lock():
            processed.count += local_count
    
    threads = []
    
    # create producer threads
    for i in range(num_pairs):
        t = threading.Thread(target=producer, args=(i,))
        threads.append(t)
        t.start()
    
    # create consumer threads
    for i in range(num_pairs):
        t = threading.Thread(target=consumer)
        threads.append(t)
        t.start()
    
    # wait for all threads to complete
    for t in threads:
        t.join()
    
    end = time.perf_counter()
    _ = getattr(processed, 'count', 0)  # prevent optimization
    return (end - start) * 1000

# fibonacci computation
def fibonacci(n):
    if n <= 1:
        return n
    
    a, b = 0, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    
    return b

# mathematical worker function
def math_worker(work_per_thread):
    local_sum = 0
    
    for _ in range(work_per_thread):
        local_sum += fibonacci(35)
        
        # additional mathematical work
        for k in range(1000):
            local_sum += k * k
    
    return local_sum

# parallel mathematical work test using multiprocessing
def parallel_math_test(num_threads, work_per_thread):
    start = time.perf_counter()
    
    with ProcessPoolExecutor(max_workers=num_threads) as executor:
        futures = [executor.submit(math_worker, work_per_thread) for _ in range(num_threads)]
        results = [f.result() for f in futures]
    
    total_sum = sum(results)
    end = time.perf_counter()
    
    _ = total_sum  # prevent optimization
    return (end - start) * 1000

# async file processing using asyncio and aiofiles
async def process_file_async(file_id, temp_dir):
    try:
        file_path = temp_dir / f"test_{file_id}.dat"
        
        # write file
        async with aiofiles.open(file_path, 'w') as f:
            for j in range(1000):
                await f.write(f"data_{file_id}_{j}\n")
        
        # read and process file
        async with aiofiles.open(file_path, 'r') as f:
            content = await f.read()
            
            # simulate processing
            line_count = content.count('\n')
            
            if line_count > 0:
                # cleanup
                os.unlink(file_path)
                return True
        
    except Exception:
        pass
    
    return False

async def async_file_test(num_files):
    start = time.perf_counter()
    
    temp_dir = Path(tempfile.mkdtemp(prefix="concurrency_test_"))
    
    try:
        tasks = [process_file_async(i, temp_dir) for i in range(num_files)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        processed = sum(1 for r in results if r is True)
        
    finally:
        # cleanup temp directory
        try:
            temp_dir.rmdir()
        except:
            pass
    
    end = time.perf_counter()
    _ = processed  # prevent optimization
    return (end - start) * 1000

# thread pool worker function
def pool_worker_task():
    # simulate varied workload
    work = 0
    for j in range(10000):
        work += j * j
    
    time.sleep(0.0001)  # 100 microseconds
    return 1

# thread pool performance test
def thread_pool_test(pool_size, total_tasks):
    start = time.perf_counter()
    
    with ThreadPoolExecutor(max_workers=pool_size) as executor:
        futures = [executor.submit(pool_worker_task) for _ in range(total_tasks)]
        results = [f.result() for f in futures]
    
    completed = sum(results)
    end = time.perf_counter()
    
    _ = completed  # prevent optimization
    return (end - start) * 1000

# wrapper for async tests
def run_async_test(async_func, *args):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(async_func(*args))
    finally:
        loop.close()

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

    total_time += run_async_test(parallel_http_test, 50 * scale_factor)
    total_time += producer_consumer_test(4, 1000 * scale_factor)
    total_time += parallel_math_test(4, 100 * scale_factor)
    total_time += run_async_test(async_file_test, 20 * scale_factor)
    total_time += thread_pool_test(8, 500 * scale_factor)

    print(f"{total_time:.3f}")

if __name__ == "__main__":
    main()