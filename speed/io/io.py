import sys
import time
import os
import json
import csv
import mmap
import random

# sequential text read reading a file line-by-line to count words
def sequential_read_test(filename):
    start = time.perf_counter()
    word_count = 0
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for line in f:
                word_count += len(line.split())
    except FileNotFoundError:
        print(f"error: file not found -> {filename}", file=sys.stderr)
        return 0.0
    
    end = time.perf_counter()
    # keep the result alive so the whole operation isn't optimized away
    _ = word_count
    return (end - start) * 1000

# random access read jump around in a binary file, tests the os/disk latency more than throughput
def random_access_test(filename, num_accesses):
    start = time.perf_counter()
    total_bytes_read = 0
    try:
        file_size = os.path.getsize(filename)
        if file_size < 4096:
            print(f"error: binary file too small -> {filename}", file=sys.stderr)
            return 0.0

        with open(filename, 'rb') as f:
            # keep it predictable
            random.seed(42)
            for _ in range(num_accesses):
                offset = random.randint(0, file_size - 4096)
                f.seek(offset)
                chunk = f.read(4096)
                total_bytes_read += len(chunk)
    except FileNotFoundError:
        print(f"error: file not found -> {filename}", file=sys.stderr)
        return 0.0
    
    end = time.perf_counter()
    _ = total_bytes_read
    return (end - start) * 1000

# memory-mapped read
def memory_map_test(filename):
    start = time.perf_counter()
    word_count = 0
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            # fileno() gets the underlying file handle for mmap
            with mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                # treat the whole file like one big string/bytes object, this is way faster than iterating line by line in python
                word_count = len(mm.read().split())
    except FileNotFoundError:
        print(f"error: file not found -> {filename}", file=sys.stderr)
        return 0.0
    except ValueError:
        # mmap can't be used on an empty file
        return 0.0
    
    end = time.perf_counter()
    _ = word_count
    return (end - start) * 1000

# csv read and process
def csv_read_and_process_test(filename):
    start = time.perf_counter()
    price_sum = 0.0
    filter_count = 0
    try:
        with open(filename, 'r', newline='', encoding='utf-8') as f:
            reader = csv.reader(f)
            next(reader) # skip header
            for row in reader:
                # row[2] is price, row[3] is category
                try:
                    price_sum += float(row[2])
                except (ValueError, IndexError):
                    # just ignore rows that are messed up
                    continue
                
                if len(row) > 3 and row[3] == "Electronics":
                    filter_count += 1
    except FileNotFoundError:
        print(f"error: file not found -> {filename}", file=sys.stderr)
        return 0.0

    end = time.perf_counter()
    _ = price_sum + filter_count
    return (end - start) * 1000

# generate and write a bunch of records to a csv file
def csv_write_test(filename, num_records):
    start = time.perf_counter()
    header = ["id", "product_name", "price", "category"]
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for i in range(num_records):
            writer.writerow([
                i,
                f"Product-{i}",
                f"{i * 1.5:.2f}",
                f"Category-{i % 10}"
            ])
    
    end = time.perf_counter()
    return (end - start) * 1000

# json dom read and process
def json_dom_read_and_process_test(filename):
    start = time.perf_counter()
    user_id = ""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # navigate the dictionary to get what we want
            user_id = data.get("metadata", {}).get("user_id", "")
    except FileNotFoundError:
        print(f"error: file not found -> {filename}", file=sys.stderr)
        return 0.0
    except json.JSONDecodeError:
        print(f"error: bad json in {filename}", file=sys.stderr)
        return 0.0

    end = time.perf_counter()
    _ = len(user_id)
    return (end - start) * 1000

# for huge files, you process them line by line, this assumes a json lines format (.jsonl) where each line is a valid json object
def json_stream_read_and_process_test(filename):
    start = time.perf_counter()
    total = 0.0
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            for line in f:
                try:
                    obj = json.loads(line)
                    total += obj.get("price", 0.0)
                except json.JSONDecodeError:
                    # skip corrupted lines
                    continue
    except FileNotFoundError:
        print(f"error: file not found -> {filename}", file=sys.stderr)
        return 0.0

    end = time.perf_counter()
    _ = total
    return (end - start) * 1000

# build a big python dictionary and dump it to a json file
def json_write_test(filename, num_records):
    start = time.perf_counter()
    
    data = {
        "metadata": {"record_count": num_records},
        "items": []
    }
    for i in range(num_records):
        data["items"].append({
            "id": i,
            "name": f"Item {i}",
            "attributes": {
                "active": True,
                "value": i * 3.14
            }
        })
    
    with open(filename, 'w', encoding='utf-8') as f:
        # separators=(',', ':') is the most compact and fastest way to write
        json.dump(data, f, separators=(',', ':'))

    end = time.perf_counter()
    return (end - start) * 1000


if __name__ == "__main__":
    scale_factor = 1
    if len(sys.argv) > 1:
        try:
            scale_factor = int(sys.argv[1])
        except ValueError:
            print("invalid scale factor, using default 1", file=sys.stderr)
            scale_factor = 1

    # files must be generated by a script before running this
    text_file = "data.txt"
    bin_file = "data.bin"
    csv_read_file = "data.csv"
    csv_write_file = "output.csv"
    json_dom_file = "data.json"
    # for streaming test, we use a .jsonl file
    json_stream_file = "data_large.jsonl"
    json_write_file = "output.json"

    # adjust workload with the scale factor
    random_accesses = 1000 * scale_factor
    csv_write_records = 100000 * scale_factor
    json_write_records = 50000 * scale_factor
    
    total_time = 0.0
    
    total_time += sequential_read_test(text_file)
    total_time += random_access_test(bin_file, random_accesses)
    total_time += memory_map_test(text_file)
    total_time += csv_read_and_process_test(csv_read_file)
    total_time += csv_write_test(csv_write_file, csv_write_records)
    total_time += json_dom_read_and_process_test(json_dom_file)
    total_time += json_stream_read_and_process_test(json_stream_file)
    total_time += json_write_test(json_write_file, json_write_records)
    
    print(f"{total_time:.3f}")