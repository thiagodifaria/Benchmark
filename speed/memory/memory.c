#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
#include <process.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

// simple arena allocator
typedef struct {
    char* buffer;
    size_t size;
    size_t used;
} arena_t;

static inline double get_time_ms() {
#ifdef _WIN32
    LARGE_INTEGER frequency, counter;
    QueryPerformanceFrequency(&frequency);
    QueryPerformanceCounter(&counter);
    return (double)counter.QuadPart * 1000.0 / frequency.QuadPart;
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1000000.0;
#endif
}

static inline uint64_t xorshift64(uint64_t* state) {
    uint64_t x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    return x;
}

// allocation patterns test - sequential, random, producer-consumer
double allocation_patterns_test(int iterations) {
    double start = get_time_ms();
    
    // sequential allocation pattern
    void** ptrs = malloc(iterations * sizeof(void*));
    for (int i = 0; i < iterations; i++) {
        ptrs[i] = malloc(64 + (i % 256));
    }
    for (int i = 0; i < iterations; i++) {
        free(ptrs[i]);
    }
    
    // random allocation pattern
    uint64_t rng_state = 42;
    for (int i = 0; i < iterations; i++) {
        size_t size = 32 + (xorshift64(&rng_state) % 512);
        ptrs[i] = malloc(size);
    }
    
    // random deallocation
    for (int i = 0; i < iterations; i++) {
        int idx = xorshift64(&rng_state) % iterations;
        if (ptrs[idx]) {
            free(ptrs[idx]);
            ptrs[idx] = NULL;
        }
    }
    
    // cleanup remaining
    for (int i = 0; i < iterations; i++) {
        if (ptrs[i]) free(ptrs[i]);
    }
    
    free(ptrs);
    
    double end = get_time_ms();
    return end - start;
}

#ifdef _WIN32
typedef struct {
    int thread_id;
    int iterations;
    volatile long* counter;
} thread_data_t;

DWORD WINAPI gc_stress_thread(LPVOID param) {
    thread_data_t* data = (thread_data_t*)param;
    uint64_t rng_state = 42 + data->thread_id;
    
    for (int i = 0; i < data->iterations; i++) {
        size_t size = 16 + (xorshift64(&rng_state) % 1024);
        void* ptr = malloc(size);
        memset(ptr, (char)(i & 0xFF), size);
        
        // simulate some work
        volatile char sum = 0;
        for (size_t j = 0; j < size; j += 8) {
            sum += ((char*)ptr)[j];
        }
        
        free(ptr);
        InterlockedIncrement(data->counter);
    }
    return 0;
}
#else
typedef struct {
    int thread_id;
    int iterations;
    volatile int* counter;
} thread_data_t;

void* gc_stress_thread(void* param) {
    thread_data_t* data = (thread_data_t*)param;
    uint64_t rng_state = 42 + data->thread_id;
    
    for (int i = 0; i < data->iterations; i++) {
        size_t size = 16 + (xorshift64(&rng_state) % 1024);
        void* ptr = malloc(size);
        memset(ptr, (char)(i & 0xFF), size);
        
        // simulate some work
        volatile char sum = 0;
        for (size_t j = 0; j < size; j += 8) {
            sum += ((char*)ptr)[j];
        }
        
        free(ptr);
        __sync_add_and_fetch(data->counter, 1);
    }
    return NULL;
}
#endif

// gc stress testing with multiple threads
double gc_stress_test(int num_threads, int iterations_per_thread) {
    double start = get_time_ms();
    
#ifdef _WIN32
    HANDLE* threads = malloc(num_threads * sizeof(HANDLE));
    thread_data_t* thread_data = malloc(num_threads * sizeof(thread_data_t));
    volatile long counter = 0;
    
    for (int i = 0; i < num_threads; i++) {
        thread_data[i].thread_id = i;
        thread_data[i].iterations = iterations_per_thread;
        thread_data[i].counter = &counter;
        threads[i] = CreateThread(NULL, 0, gc_stress_thread, &thread_data[i], 0, NULL);
    }
    
    WaitForMultipleObjects(num_threads, threads, TRUE, INFINITE);
    
    for (int i = 0; i < num_threads; i++) {
        CloseHandle(threads[i]);
    }
#else
    pthread_t* threads = malloc(num_threads * sizeof(pthread_t));
    thread_data_t* thread_data = malloc(num_threads * sizeof(thread_data_t));
    volatile int counter = 0;
    
    for (int i = 0; i < num_threads; i++) {
        thread_data[i].thread_id = i;
        thread_data[i].iterations = iterations_per_thread;
        thread_data[i].counter = &counter;
        pthread_create(&threads[i], NULL, gc_stress_thread, &thread_data[i]);
    }
    
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
#endif
    
    volatile int result = counter;
    
    free(threads);
    free(thread_data);
    
    double end = get_time_ms();
    return end - start;
}

// cache locality and fragmentation test
double cache_locality_test(int iterations) {
    double start = get_time_ms();
    
    // allocate small and large objects interleaved
    void** small_ptrs = malloc(iterations * sizeof(void*));
    void** large_ptrs = malloc(iterations * sizeof(void*));
    
    uint64_t rng_state = 42;
    
    // interleaved allocation pattern
    for (int i = 0; i < iterations; i++) {
        small_ptrs[i] = malloc(16 + (xorshift64(&rng_state) % 64));
        large_ptrs[i] = malloc(1024 + (xorshift64(&rng_state) % 4096));
        
        // access pattern to test spatial locality
        if (small_ptrs[i]) {
            memset(small_ptrs[i], (char)(i & 0xFF), 16);
        }
        if (large_ptrs[i]) {
            memset(large_ptrs[i], (char)((i + 1) & 0xFF), 1024);
        }
    }
    
    // random access pattern to stress cache
    for (int i = 0; i < iterations / 2; i++) {
        int idx1 = xorshift64(&rng_state) % iterations;
        int idx2 = xorshift64(&rng_state) % iterations;
        
        if (small_ptrs[idx1]) {
            volatile char sum = 0;
            char* ptr = (char*)small_ptrs[idx1];
            for (int j = 0; j < 16; j++) {
                sum += ptr[j];
            }
        }
        
        if (large_ptrs[idx2]) {
            volatile char sum = 0;
            char* ptr = (char*)large_ptrs[idx2];
            for (int j = 0; j < 1024; j += 64) {
                sum += ptr[j];
            }
        }
    }
    
    // cleanup
    for (int i = 0; i < iterations; i++) {
        if (small_ptrs[i]) free(small_ptrs[i]);
        if (large_ptrs[i]) free(large_ptrs[i]);
    }
    
    free(small_ptrs);
    free(large_ptrs);
    
    double end = get_time_ms();
    return end - start;
}

// simple arena allocator implementation
arena_t* arena_create(size_t size) {
    arena_t* arena = malloc(sizeof(arena_t));
    arena->buffer = malloc(size);
    arena->size = size;
    arena->used = 0;
    return arena;
}

void* arena_alloc(arena_t* arena, size_t size) {
    // align to 8 bytes
    size = (size + 7) & ~7;
    
    if (arena->used + size > arena->size) {
        return NULL; // arena full
    }
    
    void* ptr = arena->buffer + arena->used;
    arena->used += size;
    return ptr;
}

void arena_reset(arena_t* arena) {
    arena->used = 0;
}

void arena_destroy(arena_t* arena) {
    free(arena->buffer);
    free(arena);
}

// memory pool performance test
double memory_pool_test(int iterations) {
    double start = get_time_ms();
    
    // test standard allocation
    void** std_ptrs = malloc(iterations * sizeof(void*));
    for (int i = 0; i < iterations; i++) {
        std_ptrs[i] = malloc(128);
        memset(std_ptrs[i], (char)(i & 0xFF), 128);
    }
    for (int i = 0; i < iterations; i++) {
        free(std_ptrs[i]);
    }
    
    // test arena allocation
    arena_t* arena = arena_create(iterations * 128 + 1024);
    char** arena_ptrs = malloc(iterations * sizeof(char*));
    
    for (int i = 0; i < iterations; i++) {
        arena_ptrs[i] = (char*)arena_alloc(arena, 128);
        if (arena_ptrs[i]) {
            memset(arena_ptrs[i], (char)(i & 0xFF), 128);
        }
    }
    
    // batch deallocation
    arena_reset(arena);
    
    // test batch allocation
    for (int batch = 0; batch < 10; batch++) {
        for (int i = 0; i < iterations / 10; i++) {
            char* ptr = (char*)arena_alloc(arena, 128);
            if (ptr) {
                memset(ptr, (char)(i & 0xFF), 128);
            }
        }
        arena_reset(arena);
    }
    
    arena_destroy(arena);
    free(std_ptrs);
    free(arena_ptrs);
    
    double end = get_time_ms();
    return end - start;
}

// memory intensive workloads test
double memory_intensive_test(int large_size_mb) {
    double start = get_time_ms();
    
    size_t size = (size_t)large_size_mb * 1024 * 1024;
    
    // large object allocation
    char* large_array1 = malloc(size);
    char* large_array2 = malloc(size);
    
    if (!large_array1 || !large_array2) {
        if (large_array1) free(large_array1);
        if (large_array2) free(large_array2);
        return 0.0;
    }
    
    // memory bandwidth test - sequential write
    for (size_t i = 0; i < size; i += 4096) {
        large_array1[i] = (char)(i & 0xFF);
    }
    
    // memory copy operations
    memcpy(large_array2, large_array1, size);
    
    // memory bandwidth test - sequential read
    volatile long long sum = 0;
    for (size_t i = 0; i < size; i += 4096) {
        sum += large_array2[i];
    }
    
    // memory access pattern test
    uint64_t rng_state = 42;
    for (int i = 0; i < 10000; i++) {
        size_t offset = xorshift64(&rng_state) % (size - 64);
        volatile char val = large_array1[offset];
        large_array2[offset] = val + 1;
    }
    
    free(large_array1);
    free(large_array2);
    
    double end = get_time_ms();
    return end - start;
}

int main(int argc, char* argv[]) {
    int scale_factor = 1;
    if (argc > 1) {
        scale_factor = atoi(argv[1]);
        if (scale_factor <= 0) scale_factor = 1;
    }
    
    double total_time = 0.0;
    
    total_time += allocation_patterns_test(10000 * scale_factor);
    total_time += gc_stress_test(4, 2500 * scale_factor);
    total_time += cache_locality_test(5000 * scale_factor);
    total_time += memory_pool_test(8000 * scale_factor);
    total_time += memory_intensive_test(100 * scale_factor);
    
    printf("%.3f\n", total_time);
    return 0;
}