#include <iostream>
#include <vector>
#include <memory>
#include <chrono>
#include <random>
#include <thread>
#include <atomic>
#include <algorithm>
#include <cstring>

using namespace std;

// simple arena allocator class
class Arena {
private:
    vector<char> buffer;
    size_t used;
    
public:
    Arena(size_t size) : buffer(size), used(0) {}
    
    void* allocate(size_t size) {
        // align to 8 bytes
        size = (size + 7) & ~7;
        
        if (used + size > buffer.size()) {
            return nullptr;
        }
        
        void* ptr = buffer.data() + used;
        used += size;
        return ptr;
    }
    
    void reset() {
        used = 0;
    }
    
    size_t capacity() const { return buffer.size(); }
    size_t usage() const { return used; }
};

// allocation patterns test - sequential, random, producer-consumer
double allocationPatternsTest(int iterations) {
    auto start = chrono::high_resolution_clock::now();
    
    // sequential allocation pattern
    vector<unique_ptr<char[]>> ptrs;
    ptrs.reserve(iterations);
    
    for (int i = 0; i < iterations; i++) {
        size_t size = 64 + (i % 256);
        ptrs.emplace_back(make_unique<char[]>(size));
    }
    
    // clear all at once
    ptrs.clear();
    
    // random allocation pattern
    mt19937 rng(42);
    uniform_int_distribution<size_t> size_dist(32, 544);
    
    vector<void*> raw_ptrs(iterations);
    for (int i = 0; i < iterations; i++) {
        raw_ptrs[i] = malloc(size_dist(rng));
    }
    
    // random deallocation
    shuffle(raw_ptrs.begin(), raw_ptrs.end(), rng);
    for (void* ptr : raw_ptrs) {
        free(ptr);
    }
    
    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// worker function for gc stress test
void gcStressWorker(int thread_id, int iterations, atomic<int>& counter) {
    mt19937 rng(42 + thread_id);
    uniform_int_distribution<size_t> size_dist(16, 1040);
    
    for (int i = 0; i < iterations; i++) {
        size_t size = size_dist(rng);
        auto ptr = make_unique<char[]>(size);
        
        // simulate work
        fill(ptr.get(), ptr.get() + size, static_cast<char>(i & 0xFF));
        
        volatile char sum = 0;
        for (size_t j = 0; j < size; j += 8) {
            sum += ptr[j];
        }
        
        counter.fetch_add(1);
    }
}

// gc stress testing with multiple threads
double gcStressTest(int numThreads, int iterationsPerThread) {
    auto start = chrono::high_resolution_clock::now();
    
    atomic<int> counter{0};
    vector<thread> threads;
    threads.reserve(numThreads);
    
    for (int i = 0; i < numThreads; i++) {
        threads.emplace_back(gcStressWorker, i, iterationsPerThread, ref(counter));
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    volatile int result = counter.load();
    
    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// cache locality and fragmentation test
double cacheLocalityTest(int iterations) {
    auto start = chrono::high_resolution_clock::now();
    
    // allocate small and large objects interleaved
    vector<unique_ptr<char[]>> smallPtrs;
    vector<unique_ptr<char[]>> largePtrs;
    smallPtrs.reserve(iterations);
    largePtrs.reserve(iterations);
    
    mt19937 rng(42);
    uniform_int_distribution<size_t> small_dist(16, 80);
    uniform_int_distribution<size_t> large_dist(1024, 5120);
    
    // interleaved allocation pattern
    for (int i = 0; i < iterations; i++) {
        auto small_ptr = make_unique<char[]>(small_dist(rng));
        auto large_ptr = make_unique<char[]>(large_dist(rng));
        
        // access pattern to test spatial locality
        fill(small_ptr.get(), small_ptr.get() + 16, static_cast<char>(i & 0xFF));
        fill(large_ptr.get(), large_ptr.get() + 1024, static_cast<char>((i + 1) & 0xFF));
        
        smallPtrs.push_back(move(small_ptr));
        largePtrs.push_back(move(large_ptr));
    }
    
    // random access pattern to stress cache
    uniform_int_distribution<int> idx_dist(0, iterations - 1);
    for (int i = 0; i < iterations / 2; i++) {
        int idx1 = idx_dist(rng);
        int idx2 = idx_dist(rng);
        
        if (smallPtrs[idx1]) {
            volatile char sum = 0;
            char* ptr = smallPtrs[idx1].get();
            for (int j = 0; j < 16; j++) {
                sum += ptr[j];
            }
        }
        
        if (largePtrs[idx2]) {
            volatile char sum = 0;
            char* ptr = largePtrs[idx2].get();
            for (int j = 0; j < 1024; j += 64) {
                sum += ptr[j];
            }
        }
    }
    
    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// memory pool performance test
double memoryPoolTest(int iterations) {
    auto start = chrono::high_resolution_clock::now();
    
    // test standard allocation
    vector<unique_ptr<char[]>> stdPtrs;
    stdPtrs.reserve(iterations);
    
    for (int i = 0; i < iterations; i++) {
        auto ptr = make_unique<char[]>(128);
        fill(ptr.get(), ptr.get() + 128, static_cast<char>(i & 0xFF));
        stdPtrs.push_back(move(ptr));
    }
    stdPtrs.clear();
    
    // test arena allocation
    Arena arena(iterations * 128 + 1024);
    vector<char*> arenaPtrs;
    arenaPtrs.reserve(iterations);
    
    for (int i = 0; i < iterations; i++) {
        char* ptr = static_cast<char*>(arena.allocate(128));
        if (ptr) {
            fill(ptr, ptr + 128, static_cast<char>(i & 0xFF));
            arenaPtrs.push_back(ptr);
        }
    }
    
    // batch deallocation
    arena.reset();
    
    // test batch allocation
    for (int batch = 0; batch < 10; batch++) {
        for (int i = 0; i < iterations / 10; i++) {
            char* ptr = static_cast<char*>(arena.allocate(128));
            if (ptr) {
                fill(ptr, ptr + 128, static_cast<char>(i & 0xFF));
            }
        }
        arena.reset();
    }
    
    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

// memory intensive workloads test
double memoryIntensiveTest(int largeSizeMb) {
    auto start = chrono::high_resolution_clock::now();
    
    size_t size = static_cast<size_t>(largeSizeMb) * 1024 * 1024;
    
    // large object allocation
    auto largeArray1 = make_unique<char[]>(size);
    auto largeArray2 = make_unique<char[]>(size);
    
    // memory bandwidth test - sequential write
    for (size_t i = 0; i < size; i += 4096) {
        largeArray1[i] = static_cast<char>(i & 0xFF);
    }
    
    // memory copy operations
    memcpy(largeArray2.get(), largeArray1.get(), size);
    
    // memory bandwidth test - sequential read
    volatile long long sum = 0;
    for (size_t i = 0; i < size; i += 4096) {
        sum += largeArray2[i];
    }
    
    // memory access pattern test
    mt19937_64 rng(42);
    uniform_int_distribution<size_t> offset_dist(0, size - 64);
    
    for (int i = 0; i < 10000; i++) {
        size_t offset = offset_dist(rng);
        volatile char val = largeArray1[offset];
        largeArray2[offset] = val + 1;
    }
    
    auto end = chrono::high_resolution_clock::now();
    return chrono::duration_cast<chrono::microseconds>(end - start).count() / 1000.0;
}

int main(int argc, char* argv[]) {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);
    
    int scaleFactor = 1;
    if (argc > 1) {
        try {
            scaleFactor = stoi(argv[1]);
            if (scaleFactor <= 0) scaleFactor = 1;
        } catch (...) {
            cerr << "Invalid scale factor. Using default 1." << endl;
            scaleFactor = 1;
        }
    }
    
    double totalTime = 0.0;
    
    totalTime += allocationPatternsTest(10000 * scaleFactor);
    totalTime += gcStressTest(4, 2500 * scaleFactor);
    totalTime += cacheLocalityTest(5000 * scaleFactor);
    totalTime += memoryPoolTest(8000 * scaleFactor);
    totalTime += memoryIntensiveTest(100 * scaleFactor);
    
    cout << fixed;
    cout.precision(3);
    cout << totalTime << endl;
    
    return 0;
}