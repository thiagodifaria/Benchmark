use std::fs::File;
use std::io::{self, BufRead, BufReader, Read, Seek, SeekFrom};
use std::time::Instant;
use std::hint::black_box;
use std::env;

use csv::{Reader, Writer};
use memmap2::Mmap;
use serde::{Deserialize, Serialize};
use rand::{Rng, SeedableRng};
use rand::rngs::StdRng;

// debug flag - set via environment variable
fn debug_enabled() -> bool {
    env::var("RUST_BENCH_DEBUG").is_ok()
}

// debug print helper
macro_rules! debug_print {
    ($($arg:tt)*) => {
        if debug_enabled() {
            eprintln!("[DEBUG] {}", format!($($arg)*));
        }
    };
}

// sequential text read reading a file line-by-line
fn sequential_read_test(filename: &str) -> io::Result<f64> {
    debug_print!("Starting sequential read test: {}", filename);
    let start = Instant::now();

    let file = File::open(filename)?;
    let reader = BufReader::new(file);

    let mut word_count = 0;
    for line in reader.lines() {
        word_count += line?.split_whitespace().count();
    }
    
    let duration = start.elapsed();
    debug_print!("Sequential read: {} words in {:.3}ms", word_count, duration.as_secs_f64() * 1000.0);
    
    black_box(word_count);
    Ok(duration.as_secs_f64() * 1000.0)
}

// random access read jump around in a binary file
fn random_access_test(filename: &str, num_accesses: usize) -> io::Result<f64> {
    debug_print!("Starting random access test: {} with {} accesses", filename, num_accesses);
    let start = Instant::now();

    let mut file = File::open(filename)?;
    let file_size = file.metadata()?.len();

    if file_size < 4096 {
        eprintln!("error: binary file too small -> {}", filename);
        return Ok(0.0);
    }
    
    let mut rng = StdRng::seed_from_u64(42);
    let mut buffer = vec![0; 4096];
    let mut total_bytes_read = 0;

    for _ in 0..num_accesses {
        let offset = rng.gen_range(0..=file_size - 4096);
        file.seek(SeekFrom::Start(offset))?;
        let bytes_read = file.read(&mut buffer)?;
        total_bytes_read += bytes_read;
    }

    let duration = start.elapsed();
    debug_print!("Random access: {} bytes in {:.3}ms", total_bytes_read, duration.as_secs_f64() * 1000.0);
    
    black_box(total_bytes_read);
    Ok(duration.as_secs_f64() * 1000.0)
}

// memory-mapped read using the memmap2 crate
fn memory_map_test(filename: &str) -> io::Result<f64> {
    debug_print!("Starting memory map test: {}", filename);
    let start = Instant::now();

    let file = File::open(filename)?;
    let mmap = unsafe { Mmap::map(&file)? };

    let word_count = mmap.split(|&b| b == b' ' || b == b'\n' || b == b'\r').filter(|s| !s.is_empty()).count();
    
    let duration = start.elapsed();
    debug_print!("Memory map: {} words in {:.3}ms", word_count, duration.as_secs_f64() * 1000.0);
    
    black_box(word_count);
    Ok(duration.as_secs_f64() * 1000.0)
}

// csv read and process using the csv crate
fn csv_read_and_process_test(filename: &str) -> io::Result<f64> {
    debug_print!("Starting CSV read test: {}", filename);
    let start = Instant::now();
    
    let mut reader = Reader::from_path(filename)?;
    let mut price_sum = 0.0;
    let mut filter_count = 0;
    let mut record_count = 0;

    for result in reader.records() {
        let record = result?;
        record_count += 1;
        
        // record[2] is price
        if let Some(price_str) = record.get(2) {
            if let Ok(price) = price_str.parse::<f64>() {
                price_sum += price;
            }
        }
        // record[3] is category
        if let Some(category) = record.get(3) {
            if category == "Electronics" {
                filter_count += 1;
            }
        }
    }
    
    let duration = start.elapsed();
    debug_print!("CSV read: {} records, sum={:.2}, electronics={} in {:.3}ms", 
                 record_count, price_sum, filter_count, duration.as_secs_f64() * 1000.0);
    
    black_box(price_sum + filter_count as f64);
    Ok(duration.as_secs_f64() * 1000.0)
}

// generate and write a bunch of records to a csv file
fn csv_write_test(filename: &str, num_records: usize) -> io::Result<f64> {
    debug_print!("Starting CSV write test: {} records to {}", num_records, filename);
    let start = Instant::now();
    
    let mut writer = Writer::from_path(filename)?;
    writer.write_record(&["id", "product_name", "price", "category"])?;
    for i in 0..num_records {
        writer.write_record(&[
            i.to_string(),
            format!("Product-{}", i),
            format!("{:.2}", i as f64 * 1.5),
            format!("Category-{}", i % 10),
        ])?;
    }
    writer.flush()?;

    let duration = start.elapsed();
    debug_print!("CSV write: {} records in {:.3}ms", num_records, duration.as_secs_f64() * 1000.0);
    
    Ok(duration.as_secs_f64() * 1000.0)
}

// json dom read and process using serde_json
fn json_dom_read_and_process_test(filename: &str) -> io::Result<f64> {
    debug_print!("Starting JSON DOM read test: {}", filename);
    let start = Instant::now();
    
    let file = File::open(filename)?;
    let data: serde_json::Value = serde_json::from_reader(file).unwrap_or(serde_json::Value::Null);

    let user_id = data.get("metadata")
                      .and_then(|m| m.get("user_id"))
                      .and_then(|u| u.as_str())
                      .unwrap_or("");
    
    let duration = start.elapsed();
    debug_print!("JSON DOM read: user_id='{}' (len={}) in {:.3}ms", 
                 user_id, user_id.len(), duration.as_secs_f64() * 1000.0);
    
    black_box(user_id.len());
    Ok(duration.as_secs_f64() * 1000.0)
}

// json streaming read for huge files
fn json_stream_read_and_process_test(filename: &str) -> io::Result<f64> {
    debug_print!("Starting JSON stream read test: {}", filename);
    let start = Instant::now();
    
    let file = File::open(filename)?;
    let reader = BufReader::new(file);
    let mut total = 0.0;
    let mut line_count = 0;
    
    #[derive(Deserialize)]
    struct Item {
        price: f64,
    }

    for line in reader.lines() {
        line_count += 1;
        if let Ok(item) = serde_json::from_str::<Item>(&line?) {
            total += item.price;
        }
    }

    let duration = start.elapsed();
    debug_print!("JSON stream read: {} lines, total={:.2} in {:.3}ms", 
                 line_count, total, duration.as_secs_f64() * 1000.0);
    
    black_box(total);
    Ok(duration.as_secs_f64() * 1000.0)
}

// build a big rust struct and dump it to a json file
fn json_write_test(filename: &str, num_records: usize) -> io::Result<f64> {
    debug_print!("Starting JSON write test: {} records to {}", num_records, filename);
    let start = Instant::now();

    #[derive(Serialize)]
    struct Attributes {
        active: bool,
        value: f64,
    }
    #[derive(Serialize)]
    struct Item {
        id: usize,
        name: String,
        attributes: Attributes,
    }
    #[derive(Serialize)]
    struct Data {
        metadata: std::collections::HashMap<String, usize>,
        items: Vec<Item>,
    }

    let mut items = Vec::with_capacity(num_records);
    for i in 0..num_records {
        items.push(Item {
            id: i,
            name: format!("Item {}", i),
            attributes: Attributes { active: true, value: i as f64 * 3.14 },
        });
    }
    
    let mut metadata = std::collections::HashMap::new();
    metadata.insert("record_count".to_string(), num_records);

    let data = Data { metadata, items };
    let file = File::create(filename)?;
    serde_json::to_writer(file, &data)?;

    let duration = start.elapsed();
    debug_print!("JSON write: {} records in {:.3}ms", num_records, duration.as_secs_f64() * 1000.0);
    
    Ok(duration.as_secs_f64() * 1000.0)
}

fn main() {
    let scale_factor = env::args().nth(1)
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(1);

    debug_print!("Scale factor: {}", scale_factor);

    let text_file = "data/data.txt";
    let bin_file = "data/data.bin";
    let csv_read_file = "data/data.csv";
    let csv_write_file = "data/output.csv";
    let json_dom_file = "data/data.json";
    let json_stream_file = "data/data_large.jsonl";
    let json_write_file = "data/output.json";

    let random_accesses = 1000 * scale_factor;
    let csv_write_records = 100000 * scale_factor;
    let json_write_records = 50000 * scale_factor;

    let mut total_time = 0.0;

    // run each test and accumulate time, with error handling
    if let Ok(time) = sequential_read_test(text_file) { 
        total_time += time; 
    } else {
        debug_print!("Sequential read test failed");
    }
    
    if let Ok(time) = random_access_test(bin_file, random_accesses) { 
        total_time += time; 
    } else {
        debug_print!("Random access test failed");
    }
    
    if let Ok(time) = memory_map_test(text_file) { 
        total_time += time; 
    } else {
        debug_print!("Memory map test failed");
    }
    
    if let Ok(time) = csv_read_and_process_test(csv_read_file) { 
        total_time += time; 
    } else {
        debug_print!("CSV read test failed");
    }
    
    if let Ok(time) = csv_write_test(csv_write_file, csv_write_records) { 
        total_time += time; 
    } else {
        debug_print!("CSV write test failed");
    }
    
    if let Ok(time) = json_dom_read_and_process_test(json_dom_file) { 
        total_time += time; 
    } else {
        debug_print!("JSON DOM read test failed");
    }
    
    if let Ok(time) = json_stream_read_and_process_test(json_stream_file) { 
        total_time += time; 
    } else {
        debug_print!("JSON stream read test failed");
    }
    
    if let Ok(time) = json_write_test(json_write_file, json_write_records) { 
        total_time += time; 
    } else {
        debug_print!("JSON write test failed");
    }

    debug_print!("Total time: {:.3}ms", total_time);
    println!("{:.3}", total_time);
}