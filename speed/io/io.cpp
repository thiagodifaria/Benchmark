#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <chrono>
#include <numeric>
#include <random>
#include <sstream>

#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#endif

#include "json.hpp"

using namespace std;
using json = nlohmann::json;

// reads a big text file line by line, the classic way
double sequentialReadTest(const string& filename) {
    auto start = chrono::high_resolution_clock::now();

    ifstream file(filename);
    if (!file.is_open()) {
        cerr << "Error: Could not open file " << filename << endl;
        return 0.0;
    }

    string line;
    long long word_count = 0;
    while (getline(file, line)) {
        stringstream ss(line);
        string word;
        while (ss >> word) {
            word_count++;
        }
    }

    auto end = chrono::high_resolution_clock::now();
    
    // this volatile stuff is just to make sure the compiler doesn't get clever and optimize away our benchmark results
    volatile long long result = word_count;
    (void)result; // suppress unused variable warning

    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// jumps around a binary file, reading small chunks. tests random access latency
double randomAccessTest(const string& filename, int num_accesses) {
    auto start = chrono::high_resolution_clock::now();

    ifstream file(filename, ios::binary | ios::ate);
    if (!file.is_open()) {
        cerr << "Error: Could not open file " << filename << endl;
        return 0.0;
    }

    long long file_size = file.tellg();
    if (file_size < 4096) {
        cerr << "Error: Binary file is too small for this test." << endl;
        return 0.0;
    }

    mt19937 gen(42); // keep it predictable
    uniform_int_distribution<long long> dist(0, file_size - 4096);
    vector<char> buffer(4096);
    long long total_bytes_read = 0;

    for (int i = 0; i < num_accesses; ++i) {
        long long offset = dist(gen);
        file.seekg(offset);
        file.read(buffer.data(), 4096);
        total_bytes_read += file.gcount();
    }

    auto end = chrono::high_resolution_clock::now();
    volatile long long result = total_bytes_read;
    (void)result;

    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// mmap is a classic pro-gamer move for I/O
double memoryMapTest(const string& filename) {
    auto start = chrono::high_resolution_clock::now();

#ifdef _WIN32
    HANDLE fileHandle = CreateFileA(filename.c_str(), GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (fileHandle == INVALID_HANDLE_VALUE) return 0.0;

    LARGE_INTEGER fileSize;
    if (!GetFileSizeEx(fileHandle, &fileSize)) { CloseHandle(fileHandle); return 0.0; }
    
    HANDLE mappingHandle = CreateFileMappingA(fileHandle, NULL, PAGE_READONLY, 0, 0, NULL);
    if (mappingHandle == NULL) { CloseHandle(fileHandle); return 0.0; }

    const char* data = (const char*)MapViewOfFile(mappingHandle, FILE_MAP_READ, 0, 0, fileSize.QuadPart);
    if (data == NULL) { CloseHandle(mappingHandle); CloseHandle(fileHandle); return 0.0; }

    long long file_size_val = fileSize.QuadPart;
#else // POSIX
    int fd = open(filename.c_str(), O_RDONLY);
    if (fd == -1) return 0.0;

    struct stat sb;
    if (fstat(fd, &sb) == -1) { close(fd); return 0.0; }
    long long file_size_val = sb.st_size;

    const char* data = (const char*)mmap(NULL, file_size_val, PROT_READ, MAP_PRIVATE, fd, 0);
    if (data == MAP_FAILED) { close(fd); return 0.0; }
#endif

    long long word_count = 0;
    string_view view(data, file_size_val);
    size_t pos = 0;
    while(pos < view.size()){
        size_t next_space = view.find_first_of(" \t\n", pos);
        if(next_space == string_view::npos) next_space = view.size();
        if(next_space > pos) word_count++;
        pos = view.find_first_not_of(" \t\n", next_space);
        if(pos == string_view::npos) break;
    }

#ifdef _WIN32
    UnmapViewOfFile(data);
    CloseHandle(mappingHandle);
    CloseHandle(fileHandle);
#else
    munmap((void*)data, file_size_val);
    close(fd);
#endif

    auto end = chrono::high_resolution_clock::now();
    volatile long long result = word_count;
    (void)result;

    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}


// roll our own csv parser avoids pulling in a lib
double csvReadAndProcessTest(const string& filename) {
    auto start = chrono::high_resolution_clock::now();
    ifstream file(filename);
    if (!file.is_open()) return 0.0;

    string line;
    getline(file, line); // skip header

    double price_sum = 0.0;
    int filter_count = 0;

    while(getline(file, line)){
        stringstream ss(line);
        string cell;

        getline(ss, cell, ','); // ID
        getline(ss, cell, ','); // Name
        getline(ss, cell, ','); // Price
        try { price_sum += stod(cell); } catch(...) {}
        
        getline(ss, cell, ','); // Category
        if(cell == "Electronics") filter_count++;
    }

    auto end = chrono::high_resolution_clock::now();
    volatile double result = price_sum + filter_count;
    (void)result;

    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// generate and write a big csv
double csvWriteTest(const string& filename, int num_records){
    auto start = chrono::high_resolution_clock::now();
    ofstream file(filename);
    if(!file.is_open()) return 0.0;

    file << "id,product_name,price,category\n";
    for(int i = 0; i < num_records; ++i){
        file << i << ",Product-" << i << "," << (i * 1.5) << ",Category-" << (i % 10) << "\n";
    }

    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// load the whole json into memory at once
double jsonDomReadAndProcessTest(const string& filename) {
    auto start = chrono::high_resolution_clock::now();
    ifstream file(filename);
    if (!file.is_open()) return 0.0;

    json j;
    file >> j;

    string user_id = j["metadata"]["user_id"];
    
    auto end = chrono::high_resolution_clock::now();
    volatile size_t result = user_id.length();
    (void)result;

    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// a simple class to handle streaming json parsing
class StreamingSum : public json::json_sax_t {
public:
    double total = 0.0;
    bool in_items_array = false;
    bool key_is_price = false;

    bool key(string_t& val) override {
        if (val == "items") in_items_array = true;
        if (in_items_array && val == "price") key_is_price = true;
        else key_is_price = false;
        return true;
    }
    bool number_float(number_float_t val, const string_t&) override {
        if (key_is_price) total += val;
        return true;
    }
    // need to implement the other virtual functions, even if they do nothing
    bool null() override { return true; }
    bool boolean(bool) override { return true; }
    bool number_integer(number_integer_t) override { return true; }
    bool number_unsigned(number_unsigned_t) override { return true; }
    bool string(string_t&) override { return true; }
    bool start_object(size_t) override { return true; }
    bool end_object() override { return true; }
    bool start_array(size_t) override { return true; }
    bool end_array() override { in_items_array = false; return true; }
    bool binary(json::binary_t&) override { return true; }
    bool parse_error(std::size_t, const std::string&, const nlohmann::json::exception& ) override { return false; }
};

// for huge json files, you can't load it all, you have to stream it, processing as you go, this tests the kind of memory-efficient approach
double jsonStreamReadAndProcessTest(const string& filename) {
    auto start = chrono::high_resolution_clock::now();
    ifstream file(filename);
    if(!file.is_open()) return 0.0;
    
    StreamingSum consumer;
    if(!json::sax_parse(file, &consumer)){
        cerr << "JSON stream parse error on " << filename << endl;
        return 0.0;
    }

    auto end = chrono::high_resolution_clock::now();
    volatile double result = consumer.total;
    (void)result;

    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// create a big json object in memory and dump it to a file
double jsonWriteTest(const string& filename, int num_records){
    auto start = chrono::high_resolution_clock::now();
    
    json j;
    j["metadata"]["record_count"] = num_records;
    j["items"] = json::array();

    for(int i = 0; i < num_records; ++i){
        json item;
        item["id"] = i;
        item["name"] = "Item " + to_string(i);
        item["attributes"] = {{"active", true}, {"value", i * 3.14}};
        j["items"].push_back(item);
    }

    ofstream file(filename);
    if(!file.is_open()) return 0.0;
    
    // dump with no indentation for max speed
    file << j.dump(); 

    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

int main(int argc, char* argv[]) {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);

    int scale_factor = 1;
    if (argc > 1) {
        try {
            scale_factor = stoi(argv[1]);
        } catch (...) {
            cerr << "Invalid scale factor. Using default 1." << endl;
            scale_factor = 1;
        }
    }

    // these files must be generated by a separate script before running the benchmark
    const string text_file = "data.txt";
    const string bin_file = "data.bin";
    const string csv_read_file = "data.csv";
    const string csv_write_file = "output.csv";
    const string json_dom_file = "data.json";
    const string json_stream_file = "data_large.json";
    const string json_write_file = "output.json";

    const int random_accesses = 1000 * scale_factor;
    const int csv_write_records = 100000 * scale_factor;
    const int json_write_records = 50000 * scale_factor;

    double total_time = 0;

    cout << fixed;
    cout.precision(3);

    // run all the tests and accumulate the time
    total_time += sequentialReadTest(text_file);
    total_time += randomAccessTest(bin_file, random_accesses);
    total_time += memoryMapTest(text_file);
    total_time += csvReadAndProcessTest(csv_read_file);
    total_time += csvWriteTest(csv_write_file, csv_write_records);
    total_time += jsonDomReadAndProcessTest(json_dom_file);
    total_time += jsonStreamReadAndProcessTest(json_stream_file);
    total_time += jsonWriteTest(json_write_file, json_write_records);

    cout << total_time << endl;

    return 0;
}