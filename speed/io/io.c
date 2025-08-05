#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>
#include <ctype.h>
#include <math.h>
#include <float.h>
#include <limits.h>

// platform-specific includes
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#endif

// simple json parser - just enough for our benchmark
typedef struct {
    char* data;
    int pos;
    int len;
} json_parser_t;

// skip whitespace in json
void skip_whitespace(json_parser_t* parser) {
    while (parser->pos < parser->len && isspace(parser->data[parser->pos])) {
        parser->pos++;
    }
}

// find a key in json and return start of value
char* find_json_key(const char* json, const char* key) {
    char* found = strstr(json, key);
    if (!found) return NULL;
    
    // move past the key and look for the colon
    found += strlen(key);
    while (*found && (*found == '"' || *found == ' ' || *found == '\t')) found++;
    if (*found == ':') {
        found++;
        while (*found && (*found == ' ' || *found == '\t')) found++;
        return found;
    }
    return NULL;
}

// extract string value from json (very basic)
int extract_json_string(const char* start, char* output, int max_len) {
    if (*start != '"') return 0;
    start++; // skip opening quote
    
    int len = 0;
    while (*start && *start != '"' && len < max_len - 1) {
        output[len++] = *start++;
    }
    output[len] = '\0';
    return len;
}

// extract number from json
double extract_json_number(const char* start) {
    return strtod(start, NULL);
}

// high-resolution timer
double get_time_ms() {
#ifdef _WIN32
    LARGE_INTEGER frequency, counter;
    QueryPerformanceFrequency(&frequency);
    QueryPerformanceCounter(&counter);
    return (double)counter.QuadPart * 1000.0 / frequency.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1000.0 + (double)ts.tv_nsec / 1000000.0;
#endif
}

// sequential text read reading a file line-by-line
double sequentialReadTest(const char* filename) {
    double start = get_time_ms();
    FILE* file = fopen(filename, "r");
    if (!file) {
        fprintf(stderr, "error: could not read file -> %s\n", filename);
        return 0.0;
    }

    char line[2048];
    long long word_count = 0;
    
    while (fgets(line, sizeof(line), file)) {
        char* token = strtok(line, " \t\n\r");
        while (token != NULL) {
            word_count++;
            token = strtok(NULL, " \t\n\r");
        }
    }

    fclose(file);
    
    double end = get_time_ms();
    volatile long long result = word_count;
    (void)result;
    return end - start;
}

// random access read jumps around in a binary file
double randomAccessTest(const char* filename, int numAccesses) {
    double start = get_time_ms();
    FILE* file = fopen(filename, "rb");
    if (!file) { return 0.0; }

    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    rewind(file);
    if (file_size < 4096) { fclose(file); return 0.0; }

    srand(42);
    char* buffer = malloc(4096);
    if (!buffer) { fclose(file); return 0.0; }
    long long total_bytes_read = 0;

    for (int i = 0; i < numAccesses; i++) {
        long offset = rand() % (file_size - 4096);
        fseek(file, offset, SEEK_SET);
        size_t bytes_read = fread(buffer, 1, 4096, file);
        total_bytes_read += bytes_read;
    }

    free(buffer);
    fclose(file);
    double end = get_time_ms();
    volatile long long result = total_bytes_read;
    (void)result;
    return end - start;
}

// memory-mapped read using native os apis
double memoryMapTest(const char* filename) {
    double start = get_time_ms();
    long long word_count = 0;
    char* data = NULL;
    long long size = 0;

#ifdef _WIN32
    HANDLE fileHandle = CreateFileA(filename, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (fileHandle == INVALID_HANDLE_VALUE) return 0.0;
    
    LARGE_INTEGER fileSize;
    if (!GetFileSizeEx(fileHandle, &fileSize)) { CloseHandle(fileHandle); return 0.0; }
    size = fileSize.QuadPart;

    HANDLE mappingHandle = CreateFileMappingA(fileHandle, NULL, PAGE_READONLY, 0, 0, NULL);
    if (mappingHandle == NULL) { CloseHandle(fileHandle); return 0.0; }

    data = (char*)MapViewOfFile(mappingHandle, FILE_MAP_READ, 0, 0, size);
    if (data == NULL) { CloseHandle(mappingHandle); CloseHandle(fileHandle); return 0.0; }
#else // POSIX
    int fd = open(filename, O_RDONLY);
    if (fd == -1) return 0.0;

    struct stat sb;
    if (fstat(fd, &sb) == -1) { close(fd); return 0.0; }
    size = sb.st_size;

    data = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    if (data == MAP_FAILED) { close(fd); return 0.0; }
#endif

    if (data && size > 0) {
        char* data_copy = malloc(size + 1);
        if (data_copy) {
            memcpy(data_copy, data, size);
            data_copy[size] = '\0';
            
            char* token = strtok(data_copy, " \t\n\r");
            while (token != NULL) {
                word_count++;
                token = strtok(NULL, " \t\n\r");
            }
            free(data_copy);
        }
    }

#ifdef _WIN32
    UnmapViewOfFile(data);
    CloseHandle(mappingHandle);
    CloseHandle(fileHandle);
#else
    munmap(data, size);
    close(fd);
#endif
    
    double end = get_time_ms();
    volatile long long result = word_count;
    (void)result;
    return end - start;
}

// csv read and process with a simple manual parser
double csvReadAndProcessTest(const char* filename) {
    double start = get_time_ms();
    FILE* file = fopen(filename, "r");
    if (!file) return 0.0;

    char line[1024];
    fgets(line, sizeof(line), file); // skip header

    double price_sum = 0.0;
    int filter_count = 0;

    while (fgets(line, sizeof(line), file)) {
        char* tmp = strdup(line);
        if(!tmp) continue;
        char* token = strtok(tmp, ",");
        int col = 0;
        
        while (token != NULL && col < 4) {
            if (col == 2) {
                price_sum += atof(token);
            }
            if (col == 3) {
                if (strncmp(token, "Electronics", 11) == 0) {
                    filter_count++;
                }
            }
            token = strtok(NULL, ",");
            col++;
        }
        free(tmp);
    }
    
    fclose(file);
    double end = get_time_ms();
    volatile double result = price_sum + filter_count;
    (void)result;
    return end - start;
}

// generate and write a bunch of records to a csv file
double csvWriteTest(const char* filename, int numRecords) {
    double start = get_time_ms();
    FILE* file = fopen(filename, "w");
    if (!file) return 0.0;

    fprintf(file, "id,product_name,price,category\n");
    for (int i = 0; i < numRecords; i++) {
        fprintf(file, "%d,Product-%d,%.2f,Category-%d\n", i, i, (double)i * 1.5, i % 10);
    }

    fclose(file);
    double end = get_time_ms();
    return end - start;
}

// helper to read a whole file into a buffer
char* read_file_to_buffer(const char* filename, long* length_out) {
    FILE* file = fopen(filename, "rb");
    if (!file) return NULL;
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    if (length < 0) { fclose(file); return NULL; }
    char* buffer = malloc(length + 1);
    if (!buffer) { fclose(file); return NULL; }
    if (fread(buffer, 1, length, file) != (size_t)length) {
        free(buffer);
        fclose(file);
        return NULL;
    }
    buffer[length] = '\0';
    *length_out = length;
    fclose(file);
    return buffer;
}

// json dom read and process using simple string parsing
double jsonDomReadAndProcessTest(const char* filename) {
    double start = get_time_ms();
    long file_len = 0;
    char* file_content = read_file_to_buffer(filename, &file_len);
    if (!file_content) return 0.0;

    // look for "user_id" key in the json
    char* user_id_start = find_json_key(file_content, "\"user_id\"");
    char user_id[256] = "";
    
    if (user_id_start) {
        extract_json_string(user_id_start, user_id, sizeof(user_id));
    }
    
    volatile size_t result = strlen(user_id);
    (void)result;

    free(file_content);
    double end = get_time_ms();
    return end - start;
}

// json streaming read assumes json lines format
double jsonStreamReadAndProcessTest(const char* filename) {
    double start = get_time_ms();
    FILE* file = fopen(filename, "r");
    if (!file) return 0.0;

    char line[2048];
    double total = 0.0;

    while (fgets(line, sizeof(line), file)) {
        // look for "price" field in each line
        char* price_start = find_json_key(line, "\"price\"");
        if (price_start) {
            total += extract_json_number(price_start);
        }
    }
    
    fclose(file);
    double end = get_time_ms();
    volatile double result = total;
    (void)result;
    return end - start;
}

// build a json string manually and write to file
double jsonWriteTest(const char* filename, int numRecords) {
    double start = get_time_ms();
    FILE* file = fopen(filename, "w");
    if (!file) return 0.0;

    // write json manually - faster than parsing
    fprintf(file, "{\"metadata\":{\"record_count\":%d},\"items\":[", numRecords);
    
    for (int i = 0; i < numRecords; i++) {
        if (i > 0) fprintf(file, ",");
        fprintf(file, "{\"id\":%d,\"name\":\"Item %d\",\"attributes\":{\"active\":true,\"value\":%.2f}}", 
                i, i, (double)i * 3.14);
    }
    
    fprintf(file, "]}");
    fclose(file);
    
    double end = get_time_ms();
    return end - start;
}

int main(int argc, char* argv[]) {
    int scale_factor = 1;
    if (argc > 1) {
        scale_factor = atoi(argv[1]);
        if (scale_factor <= 0) scale_factor = 1;
    }

    const char* text_file = "data.txt";
    const char* bin_file = "data.bin";
    const char* csv_read_file = "data.csv";
    const char* csv_write_file = "output.csv";
    const char* json_dom_file = "data.json";
    const char* json_stream_file = "data_large.jsonl";
    const char* json_write_file = "output.json";

    int random_accesses = 1000 * scale_factor;
    int csv_write_records = 100000 * scale_factor;
    int json_write_records = 50000 * scale_factor;

    double total_time = 0.0;

    total_time += sequentialReadTest(text_file);
    total_time += randomAccessTest(bin_file, random_accesses);
    total_time += memoryMapTest(text_file);
    total_time += csvReadAndProcessTest(csv_read_file);
    total_time += csvWriteTest(csv_write_file, csv_write_records);
    total_time += jsonDomReadAndProcessTest(json_dom_file);
    total_time += jsonStreamReadAndProcessTest(json_stream_file);
    total_time += jsonWriteTest(json_write_file, json_write_records);

    printf("%.3f\n", total_time);
    return 0;
}