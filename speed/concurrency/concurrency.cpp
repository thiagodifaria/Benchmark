#include <iostream>
#include <vector>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <future>
#include <atomic>
#include <chrono>
#include <random>
#include <fstream>
#include <filesystem>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#else
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#endif

using namespace std;
using namespace chrono;

// thread-safe queue for producer-consumer
template<typename T>
class SafeQueue {
private:
    mutable mutex mtx;
    queue<T> data_queue;
    condition_variable data_cond;
    
public:
    void push(T item) {
        lock_guard<mutex> lock(mtx);
        data_queue.push(item);
        data_cond.notify_one();
    }
    
    bool try_pop(T& item) {
        lock_guard<mutex> lock(mtx);
        if (data_queue.empty()) return false;
        item = data_queue.front();
        data_queue.pop();
        return true;
    }
    
    void wait_and_pop(T& item) {
        unique_lock<mutex> lock(mtx);
        while (data_queue.empty()) {
            data_cond.wait(lock);
        }
        item = data_queue.front();
        data_queue.pop();
    }
    
    bool empty() const {
        lock_guard<mutex> lock(mtx);
        return data_queue.empty();
    }
};

// simple http client function
bool send_http_request(const string& host, int port, const string& path) {
#ifdef _WIN32
    WSADATA wsaData;
    if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) return false;
#endif
    
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return false;
    
    sockaddr_in server_addr{};
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    inet_pton(AF_INET, host.c_str(), &server_addr.sin_addr);
    
    bool success = false;
    if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) == 0) {
        string request = "GET " + path + " HTTP/1.1\r\nHost: " + host + "\r\n\r\n";
        send(sock, request.c_str(), request.length(), 0);
        
        char buffer[1024];
        recv(sock, buffer, sizeof(buffer), 0);
        success = true;
    }
    
#ifdef _WIN32
    closesocket(sock);
    WSACleanup();
#else
    close(sock);
#endif
    
    return success;
}

// parallel http requests test
double parallel_http_test(int num_requests) {
    auto start = high_resolution_clock::now();
    
    vector<future<bool>> futures;
    futures.reserve(num_requests);
    
    for (int i = 0; i < num_requests; i++) {
        futures.emplace_back(async(launch::async, []() {
            return send_http_request("127.0.0.1", 8000, "/fast");
        }));
    }
    
    int successful = 0;
    for (auto& fut : futures) {
        if (fut.get()) successful++;
    }
    
    auto end = high_resolution_clock::now();
    volatile int result = successful;
    (void)result;
    
    return duration_cast<microseconds>(end - start).count() / 1000.0;
}

// producer-consumer queue test
double producer_consumer_test(int num_pairs, int items_per_thread) {
    auto start = high_resolution_clock::now();
    
    SafeQueue<int> task_queue;
    atomic<int> total_processed{0};
    
    vector<thread> producers, consumers;
    
    // create producer threads
    for (int i = 0; i < num_pairs; i++) {
        producers.emplace_back([&task_queue, items_per_thread, i]() {
            for (int j = 0; j < items_per_thread; j++) {
                task_queue.push(i * 1000 + j);
            }
        });
    }
    
    // create consumer threads
    for (int i = 0; i < num_pairs; i++) {
        consumers.emplace_back([&task_queue, &total_processed, items_per_thread]() {
            for (int j = 0; j < items_per_thread; j++) {
                int item;
                task_queue.wait_and_pop(item);
                
                // simulate processing
                volatile int dummy = item * item;
                (void)dummy;
                
                total_processed++;
            }
        });
    }
    
    // wait for all threads to complete
    for (auto& t : producers) t.join();
    for (auto& t : consumers) t.join();
    
    auto end = high_resolution_clock::now();
    volatile int result = total_processed.load();
    (void)result;
    
    return duration_cast<microseconds>(end - start).count() / 1000.0;
}

// mathematical computation function
long long fibonacci_iterative(int n) {
    if (n <= 1) return n;
    
    long long a = 0, b = 1;
    for (int i = 2; i <= n; i++) {
        long long temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// parallel mathematical work test
double parallel_math_test(int num_threads, int work_per_thread) {
    auto start = high_resolution_clock::now();
    
    atomic<long long> total_sum{0};
    vector<thread> workers;
    
    for (int i = 0; i < num_threads; i++) {
        workers.emplace_back([&total_sum, work_per_thread, i]() {
            long long local_sum = 0;
            
            for (int j = 0; j < work_per_thread; j++) {
                local_sum += fibonacci_iterative(35);
                
                // additional mathematical work
                for (int k = 0; k < 1000; k++) {
                    local_sum += k * k;
                }
            }
            
            total_sum += local_sum;
        });
    }
    
    for (auto& worker : workers) {
        worker.join();
    }
    
    auto end = high_resolution_clock::now();
    volatile long long result = total_sum.load();
    (void)result;
    
    return duration_cast<microseconds>(end - start).count() / 1000.0;
}

// async file processing test
double async_file_test(int num_files) {
    auto start = high_resolution_clock::now();
    
    atomic<int> processed_count{0};
    vector<future<bool>> file_futures;
    
    // create temporary directory
    filesystem::path temp_dir = filesystem::temp_directory_path() / "concurrency_test";
    filesystem::create_directories(temp_dir);
    
    for (int i = 0; i < num_files; i++) {
        file_futures.emplace_back(async(launch::async, [i, temp_dir]() {
            try {
                string filename = (temp_dir / ("test_" + to_string(i) + ".dat")).string();
                
                // write file
                {
                    ofstream out_file(filename);
                    if (!out_file) return false;
                    
                    for (int j = 0; j < 1000; j++) {
                        out_file << "data_" << i << "_" << j << "\n";
                    }
                }
                
                // read and process file
                {
                    ifstream in_file(filename);
                    if (!in_file) return false;
                    
                    string line;
                    int line_count = 0;
                    while (getline(in_file, line)) {
                        line_count++;
                        
                        // simulate processing
                        volatile size_t len = line.length();
                        (void)len;
                    }
                    
                    if (line_count == 0) return false;
                }
                
                // cleanup
                filesystem::remove(filename);
                return true;
                
            } catch (const exception&) {
                return false;
            }
        }));
    }
    
    // collect results
    for (auto& fut : file_futures) {
        if (fut.get()) processed_count++;
    }
    
    // cleanup temp directory
    filesystem::remove_all(temp_dir);
    
    auto end = high_resolution_clock::now();
    volatile int result = processed_count.load();
    (void)result;
    
    return duration_cast<microseconds>(end - start).count() / 1000.0;
}

// thread pool implementation
class ThreadPool {
private:
    vector<thread> workers;
    queue<function<void()>> tasks;
    mutex queue_mutex;
    condition_variable condition;
    bool stop;
    
public:
    explicit ThreadPool(size_t threads) : stop(false) {
        for (size_t i = 0; i < threads; ++i) {
            workers.emplace_back([this] {
                while (true) {
                    function<void()> task;
                    
                    {
                        unique_lock<mutex> lock(this->queue_mutex);
                        this->condition.wait(lock, [this] { return this->stop || !this->tasks.empty(); });
                        
                        if (this->stop && this->tasks.empty()) return;
                        
                        task = move(this->tasks.front());
                        this->tasks.pop();
                    }
                    
                    task();
                }
            });
        }
    }
    
    template<class F>
    auto enqueue(F&& f) -> future<typename result_of<F()>::type> {
        using return_type = typename result_of<F()>::type;
        
        auto task = make_shared<packaged_task<return_type()>>(forward<F>(f));
        future<return_type> res = task->get_future();
        
        {
            unique_lock<mutex> lock(queue_mutex);
            if (stop) throw runtime_error("enqueue on stopped ThreadPool");
            tasks.emplace([task]() { (*task)(); });
        }
        
        condition.notify_one();
        return res;
    }
    
    ~ThreadPool() {
        {
            unique_lock<mutex> lock(queue_mutex);
            stop = true;
        }
        
        condition.notify_all();
        
        for (thread& worker : workers) {
            worker.join();
        }
    }
};

// thread pool performance test
double thread_pool_test(int pool_size, int total_tasks) {
    auto start = high_resolution_clock::now();
    
    ThreadPool pool(pool_size);
    atomic<int> completed{0};
    vector<future<void>> results;
    
    for (int i = 0; i < total_tasks; i++) {
        results.emplace_back(pool.enqueue([&completed, i]() {
            // simulate varied workload
            volatile long long work = 0;
            for (int j = 0; j < 10000; j++) {
                work += j * j;
            }
            
            this_thread::sleep_for(chrono::microseconds(100));
            completed++;
        }));
    }
    
    // wait for all tasks to complete
    for (auto& result : results) {
        result.wait();
    }
    
    auto end = high_resolution_clock::now();
    volatile int result = completed.load();
    (void)result;
    
    return duration_cast<microseconds>(end - start).count() / 1000.0;
}

int main(int argc, char* argv[]) {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);
    
    int scale_factor = 1;
    if (argc > 1) {
        try {
            scale_factor = stoi(argv[1]);
            if (scale_factor <= 0) scale_factor = 1;
        } catch (...) {
            cerr << "Invalid scale factor. Using default 1." << endl;
            scale_factor = 1;
        }
    }

    double total_time = 0.0;

    total_time += parallel_http_test(50 * scale_factor);
    total_time += producer_consumer_test(4, 1000 * scale_factor);
    total_time += parallel_math_test(4, 100 * scale_factor);
    total_time += async_file_test(20 * scale_factor);
    total_time += thread_pool_test(8, 500 * scale_factor);

    cout << fixed;
    cout.precision(3);
    cout << total_time << endl;

    return 0;
}