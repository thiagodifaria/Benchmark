# this script generates all the necessary dependencies files for the i/o benchmarks
import sys
import json
import csv
import os
import random

def generate_text_file(filename, size_mb):
    print(f"Generating text file: {filename} ({size_mb} mb)")
    # a reasonably interesting paragraph
    paragraph = "lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n"
    target_size = size_mb * 1024 * 1024
    with open(filename, 'w', encoding='utf-8') as f:
        while f.tell() < target_size:
            f.write(paragraph)

def generate_binary_file(filename, size_mb):
    print(f"Generating binary file: {filename} ({size_mb} mb)")
    target_size = size_mb * 1024 * 1024
    chunk = os.urandom(1024)
    with open(filename, 'wb') as f:
        for _ in range(target_size // 1024):
            f.write(chunk)

def generate_csv_file(filename, num_records):
    print(f"Generating csv file: {filename} ({num_records} records)")
    header = ["id", "product_name", "price", "category"]
    categories = ["Electronics", "Books", "Home", "Toys", "Clothing"]
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for i in range(num_records):
            writer.writerow([
                i,
                f"Product-{i}",
                f"{random.uniform(5.0, 500.0):.2f}",
                random.choice(categories)
            ])

def generate_json_dom_file(filename):
    print(f"Generating json dom file: {filename}")
    data = {
        "metadata": {
            "source": "benchmark_generator",
            "timestamp": "2025-08-03T12:00:00Z",
            "user_id": "a7b3c9d8-e4f5-4g6h-7i8j-k9l0m1n2o3p4"
        },
        "config": {"retries": 3, "timeout": 5000, "active": True},
        "data_points": [random.randint(1, 100) for _ in range(50)]
    }
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(data, f)

def generate_json_stream_file(filename, num_records):
    print(f"Generating json stream file: {filename} ({num_records} records)")
    with open(filename, 'w', encoding='utf-8') as f:
        for i in range(num_records):
            obj = {
                "id": f"record_{i}",
                "timestamp": f"2025-01-01T{i//3600:02d}:{(i//60)%60:02d}:{i%60:02d}Z",
                "price": round(random.uniform(10.0, 200.0), 2),
                "active": random.choice([True, False])
            }
            # write each json object on its own line
            json.dump(obj, f)
            f.write('\n')

if __name__ == '__main__':
    scale_factor = 1
    if len(sys.argv) > 1:
        try:
            scale_factor = int(sys.argv[1])
        except ValueError:
            scale_factor = 1
    
    # define the output directory for generated data
    output_dir = "data"
    os.makedirs(output_dir, exist_ok=True)

    # adjust workload with the scale factor
    text_size_mb = 50 * scale_factor
    bin_size_mb = 50 * scale_factor
    csv_records = 500000 * scale_factor
    jsonl_records = 500000 * scale_factor

    generate_text_file(os.path.join(output_dir, "data.txt"), text_size_mb)
    generate_binary_file(os.path.join(output_dir, "data.bin"), bin_size_mb)
    generate_csv_file(os.path.join(output_dir, "data.csv"), csv_records)
    generate_json_dom_file(os.path.join(output_dir, "data.json"))
    generate_json_stream_file(os.path.join(output_dir, "data_large.jsonl"), jsonl_records)
    
    print("Data generation complete")