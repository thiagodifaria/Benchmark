use std::env;
use std::time::Instant;
use std::thread;
use std::sync::{Arc, atomic::{AtomicUsize, Ordering}};
use std::hint::black_box;

// simple arena allocator
struct Arena {
    buffer: Vec<u8>,
    used: usize,
}

impl Arena {
    fn new(size: usize) -> Self {
        Arena {
            buffer: vec![0; size],
            used: 0,
        }
    }
    
    fn allocate(&mut self, size: usize) -> Option<*mut u8> {
        // align to 8 bytes
        let aligned_size = (size + 7) & !7;
        
        if self.used + aligned_size > self.buffer.len() {
            return None;
        }
        
        let ptr = unsafe { self.buffer.as_mut_ptr().add(self.used) };
        self.used += aligned_size;
        Some(ptr)
    }
    
    fn reset(&mut self) {
        self.used = 0;
    }
}

// simple xorshift rng
struct XorShift64 {
    state: u64,
}

impl XorShift64 {
    fn new(seed: u64) -> Self {
        XorShift64 { state: seed }
    }
    
    fn next(&mut self) -> u64 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 7;
        self.state ^= self.state << 17;
        self.state
    }
}

// allocation patterns test - sequential, random, producer-consumer
fn allocation_patterns_test(iterations: usize) -> f64 {
    let start = Instant::now();
    
    // sequential allocation pattern
    let mut ptrs = Vec::with_capacity(iterations);
    for i in 0..iterations {
        let size = 64 + (i % 256);
        ptrs.push(vec![0u8; size]);
    }
    ptrs.clear();
    
    // random allocation pattern
    let mut rng = XorShift64::new(42);
    let mut raw_ptrs = Vec::with_capacity(iterations);
    
    for _ in 0..iterations {
        let size = 32 + (rng.next() % 512) as usize;
        let layout = std::alloc::Layout::from_size_align(size, 1).unwrap();
        let ptr = unsafe { std::alloc::alloc(layout) };
        raw_ptrs.push((ptr, layout));
    }
    
    // random deallocation
    raw_ptrs.shuffle(&mut thread_rng());
    for (ptr, layout) in raw_ptrs {
        unsafe { std::alloc::dealloc(ptr, layout) };
    }
    
    let duration = start.elapsed();
    black_box(iterations);
    duration.as_secs_f64() * 1000.0
}

use rand::seq::SliceRandom;
use rand::thread_rng;

// worker function for gc stress test
fn gc_stress_worker(thread_id: usize, iterations: usize, counter: Arc<AtomicUsize>) {
    let mut rng = XorShift64::new(42 + thread_id as u64);
    
    for i in 0..iterations {
        let size = 16 + (rng.next() % 1024) as usize;
        let mut data = vec![0u8; size];
        
        // simulate work
        data.fill((i & 0xFF) as u8);
        
        let mut sum = 0u8;
        for j in (0..size).step_by(8) {
            sum = sum.wrapping_add(data[j]);
        }
        black_box(sum);
        
        counter.fetch_add(1, Ordering::Relaxed);
    }
}

// gc stress testing with multiple threads
fn gc_stress_test(num_threads: usize, iterations_per_thread: usize) -> f64 {
    let start = Instant::now();
    
    let counter = Arc::new(AtomicUsize::new(0));
    let mut handles = Vec::new();
    
    for i in 0..num_threads {
        let counter_clone = Arc::clone(&counter);
        let handle = thread::spawn(move || {
            gc_stress_worker(i, iterations_per_thread, counter_clone);
        });
        handles.push(handle);
    }
    
    for handle in handles {
        handle.join().unwrap();
    }
    
    let result = counter.load(Ordering::Relaxed);
    black_box(result);
    
    let duration = start.elapsed();
    duration.as_secs_f64() * 1000.0
}

// cache locality and fragmentation test
fn cache_locality_test(iterations: usize) -> f64 {
    let start = Instant::now();
    
    // allocate small and large objects interleaved
    let mut small_ptrs = Vec::with_capacity(iterations);
    let mut large_ptrs = Vec::with_capacity(iterations);
    let mut rng = XorShift64::new(42);
    
    // interleaved allocation pattern
    for i in 0..iterations {
        let small_size = 16 + (rng.next() % 64) as usize;
        let large_size = 1024 + (rng.next() % 4096) as usize;
        
        let mut small_vec = vec![(i & 0xFF) as u8; small_size];
        let mut large_vec = vec![((i + 1) & 0xFF) as u8; large_size];
        
        // access pattern to test spatial locality
        small_vec[0] = (i & 0xFF) as u8;
        large_vec[0] = ((i + 1) & 0xFF) as u8;
        
        small_ptrs.push(small_vec);
        large_ptrs.push(large_vec);
    }
    
    // random access pattern to stress cache
    for _ in 0..iterations / 2 {
        let idx1 = (rng.next() % iterations as u64) as usize;
        let idx2 = (rng.next() % iterations as u64) as usize;
        
        if let Some(small_vec) = small_ptrs.get(idx1) {
            let mut sum = 0u8;
            for &byte in small_vec.iter().take(16) {
                sum = sum.wrapping_add(byte);
            }
            black_box(sum);
        }
        
        if let Some(large_vec) = large_ptrs.get(idx2) {
            let mut sum = 0u8;
            for i in (0..1024.min(large_vec.len())).step_by(64) {
                sum = sum.wrapping_add(large_vec[i]);
            }
            black_box(sum);
        }
    }
    
    let duration = start.elapsed();
    duration.as_secs_f64() * 1000.0
}

// memory pool performance test
fn memory_pool_test(iterations: usize) -> f64 {
    let start = Instant::now();
    
    // test standard allocation
    let mut std_ptrs = Vec::with_capacity(iterations);
    for i in 0..iterations {
        let mut data = vec![(i & 0xFF) as u8; 128];
        data.fill((i & 0xFF) as u8);
        std_ptrs.push(data);
    }
    std_ptrs.clear();
    
    // test arena allocation
    let mut arena = Arena::new(iterations * 128 + 1024);
    let mut arena_ptrs = Vec::with_capacity(iterations);
    
    for i in 0..iterations {
        if let Some(ptr) = arena.allocate(128) {
            unsafe {
                std::ptr::write_bytes(ptr, (i & 0xFF) as u8, 128);
            }
            arena_ptrs.push(ptr);
        }
    }
    
    // batch deallocation
    arena.reset();
    
    // test batch allocation
    for _ in 0..10 {
        for i in 0..iterations / 10 {
            if let Some(ptr) = arena.allocate(128) {
                unsafe {
                    std::ptr::write_bytes(ptr, (i & 0xFF) as u8, 128);
                }
            }
        }
        arena.reset();
    }
    
    let duration = start.elapsed();
    duration.as_secs_f64() * 1000.0
}

// memory intensive workloads test
fn memory_intensive_test(large_size_mb: usize) -> f64 {
    let start = Instant::now();
    
    let size = large_size_mb * 1024 * 1024;
    
    // large object allocation
    let mut large_array1 = vec![0u8; size];
    let mut large_array2 = vec![0u8; size];
    
    // memory bandwidth test - sequential write
    for i in (0..size).step_by(4096) {
        large_array1[i] = (i & 0xFF) as u8;
    }
    
    // memory copy operations
    large_array2.copy_from_slice(&large_array1);
    
    // memory bandwidth test - sequential read
    let mut sum = 0i64;
    for i in (0..size).step_by(4096) {
        sum += large_array2[i] as i64;
    }
    black_box(sum);
    
    // memory access pattern test
    let mut rng = XorShift64::new(42);
    for _ in 0..10000 {
        let offset = (rng.next() % (size - 64) as u64) as usize;
        let val = large_array1[offset];
        large_array2[offset] = val.wrapping_add(1);
    }
    
    let duration = start.elapsed();
    duration.as_secs_f64() * 1000.0
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut scale_factor = 1;
    
    if args.len() > 1 {
        match args[1].parse::<usize>() {
            Ok(factor) => {
                if factor > 0 {
                    scale_factor = factor;
                }
            }
            Err(_) => {
                eprintln!("Invalid scale factor. Using default 1.");
            }
        }
    }
    
    let mut total_time = 0.0;
    
    total_time += allocation_patterns_test(10000 * scale_factor);
    total_time += gc_stress_test(4, 2500 * scale_factor);
    total_time += cache_locality_test(5000 * scale_factor);
    total_time += memory_pool_test(8000 * scale_factor);
    total_time += memory_intensive_test(100 * scale_factor);
    
    println!("{:.3}", total_time);
}