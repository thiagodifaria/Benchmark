use std::env;
use std::sync::{Arc, Mutex, mpsc};
use std::sync::atomic::{AtomicI32, AtomicI64, Ordering};
use std::thread;
use std::time::{Duration, Instant};
use std::fs::{self, File};
use std::io::{Write, Read};
use std::path::Path;

// parallel http requests test using reqwest
async fn parallel_http_test(num_requests: usize) -> f64 {
    let start = Instant::now();
    
    let client = reqwest::Client::new();
    let mut handles = Vec::new();
    
    for _ in 0..num_requests {
        let client = client.clone();
        let handle = tokio::spawn(async move {
            match client.get("http://127.0.0.1:8000/fast").send().await {
                Ok(response) => {
                    let _ = response.text().await;
                    true
                }
                Err(_) => false,
            }
        });
        handles.push(handle);
    }
    
    let mut successful = 0;
    for handle in handles {
        if let Ok(result) = handle.await {
            if result {
                successful += 1;
            }
        }
    }
    
    let duration = start.elapsed();
    std::hint::black_box(successful);
    duration.as_secs_f64() * 1000.0
}

// producer-consumer queue test using channels
fn producer_consumer_test(num_pairs: usize, items_per_thread: usize) -> f64 {
    let start = Instant::now();
    
    let (tx, rx) = mpsc::channel();
    let processed = Arc::new(AtomicI32::new(0));
    
    let mut handles = Vec::new();
    
    // create producer threads
    for i in 0..num_pairs {
        let tx = tx.clone();
        let handle = thread::spawn(move || {
            for j in 0..items_per_thread {
                let item = i * 1000 + j;
                tx.send(item).unwrap();
            }
        });
        handles.push(handle);
    }
    
    // drop the main sender
    drop(tx);
    
    // create consumer threads
    for _ in 0..num_pairs {
        let rx = rx.clone();
        let processed = processed.clone();
        let handle = thread::spawn(move || {
            for _ in 0..items_per_thread {
                if let Ok(item) = rx.recv() {
                    // simulate processing
                    let _dummy = item * item;
                    processed.fetch_add(1, Ordering::Relaxed);
                }
            }
        });
        handles.push(handle);
    }
    
    // wait for all threads to complete
    for handle in handles {
        handle.join().unwrap();
    }
    
    let duration = start.elapsed();
    std::hint::black_box(processed.load(Ordering::Relaxed));
    duration.as_secs_f64() * 1000.0
}

// fibonacci computation
fn fibonacci(n: u64) -> u64 {
    if n <= 1 {
        return n;
    }
    
    let mut a = 0;
    let mut b = 1;
    for _ in 2..=n {
        let temp = a + b;
        a = b;
        b = temp;
    }
    b
}

// parallel mathematical work test
fn parallel_math_test(num_threads: usize, work_per_thread: usize) -> f64 {
    let start = Instant::now();
    
    let total_sum = Arc::new(AtomicI64::new(0));
    let mut handles = Vec::new();
    
    for _ in 0..num_threads {
        let total_sum = total_sum.clone();
        let handle = thread::spawn(move || {
            let mut local_sum = 0i64;
            
            for _ in 0..work_per_thread {
                local_sum += fibonacci(35) as i64;
                
                // additional mathematical work
                for k in 0..1000 {
                    local_sum += (k * k) as i64;
                }
            }
            
            total_sum.fetch_add(local_sum, Ordering::Relaxed);
        });
        handles.push(handle);
    }
    
    for handle in handles {
        handle.join().unwrap();
    }
    
    let duration = start.elapsed();
    std::hint::black_box(total_sum.load(Ordering::Relaxed));
    duration.as_secs_f64() * 1000.0
}

// async file processing test using tokio
async fn async_file_test(num_files: usize) -> f64 {
    let start = Instant::now();
    
    let temp_dir = tempfile::tempdir().unwrap();
    let processed = Arc::new(AtomicI32::new(0));
    
    let mut handles = Vec::new();
    
    for i in 0..num_files {
        let temp_dir = temp_dir.path().to_path_buf();
        let processed = processed.clone();
        
        let handle = tokio::spawn(async move {
            let file_path = temp_dir.join(format!("test_{}.dat", i));
            
            // write file
            let mut file_content = String::new();
            for j in 0..1000 {
                file_content.push_str(&format!("data_{}_{}\n", i, j));
            }
            
            if let Ok(mut file) = File::create(&file_path) {
                if file.write_all(file_content.as_bytes()).is_ok() {
                    drop(file);
                    
                    // read and process file
                    if let Ok(mut file) = File::open(&file_path) {
                        let mut content = String::new();
                        if file.read_to_string(&mut content).is_ok() {
                            // simulate processing
                            let line_count = content.lines().count();
                            
                            if line_count > 0 {
                                processed.fetch_add(1, Ordering::Relaxed);
                            }
                        }
                    }
                    
                    // cleanup
                    let _ = fs::remove_file(&file_path);
                }
            }
        });
        
        handles.push(handle);
    }
    
    for handle in handles {
        let _ = handle.await;
    }
    
    let duration = start.elapsed();
    std::hint::black_box(processed.load(Ordering::Relaxed));
    duration.as_secs_f64() * 1000.0
}

// thread pool performance test using rayon
fn thread_pool_test(pool_size: usize, total_tasks: usize) -> f64 {
    let start = Instant::now();
    
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(pool_size)
        .build()
        .unwrap();
    
    let completed = Arc::new(AtomicI32::new(0));
    
    pool.scope(|s| {
        for _ in 0..total_tasks {
            let completed = completed.clone();
            s.spawn(move |_| {
                // simulate varied workload
                let mut work = 0i64;
                for j in 0..10000 {
                    work += (j * j) as i64;
                }
                
                thread::sleep(Duration::from_micros(100));
                completed.fetch_add(1, Ordering::Relaxed);
                
                std::hint::black_box(work);
            });
        }
    });
    
    let duration = start.elapsed();
    std::hint::black_box(completed.load(Ordering::Relaxed));
    duration.as_secs_f64() * 1000.0
}

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();
    let mut scale_factor = 1;
    
    if args.len() > 1 {
        match args[1].parse::<usize>() {
            Ok(factor) if factor > 0 => scale_factor = factor,
            _ => {
                eprintln!("Invalid scale factor. Using default 1.");
            }
        }
    }

    let mut total_time = 0.0;

    total_time += parallel_http_test(50 * scale_factor).await;
    total_time += producer_consumer_test(4, 1000 * scale_factor);
    total_time += parallel_math_test(4, 100 * scale_factor);
    total_time += async_file_test(20 * scale_factor).await;
    total_time += thread_pool_test(8, 500 * scale_factor);

    println!("{:.3}", total_time);
}