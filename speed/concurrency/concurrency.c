#define _DEFAULT_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#ifdef _WIN32
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#pragma comment(lib, "ws2_32.lib")
#else
#include <sys/time.h>
#include <fcntl.h>
#endif

#define MAX_THREADS 16
#define BUFFER_SIZE 1024
#define QUEUE_SIZE 1000

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

// producer-consumer queue structure
typedef struct {
    int items[QUEUE_SIZE];
    int front, rear, count;
    pthread_mutex_t mutex;
    pthread_cond_t not_full, not_empty;
} queue_t;

typedef struct {
    int thread_id;
    int iterations;
    queue_t* queue;
    volatile int* counter;
} thread_data_t;

// parallel http requests test
double parallel_http_test(int num_requests) {
    double start = get_time_ms();
    
    // simulate http requests to localhost:8000
    volatile int completed = 0;
    
#pragma omp parallel for
    for (int i = 0; i < num_requests; i++) {
        int sock = socket(AF_INET, SOCK_STREAM, 0);
        if (sock < 0) continue;
        
        struct sockaddr_in server_addr;
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(8000);
        server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        
        if (connect(sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) == 0) {
            char request[] = "GET /fast HTTP/1.1\r\nHost: localhost\r\n\r\n";
            send(sock, request, strlen(request), 0);
            
            char response[BUFFER_SIZE];
            recv(sock, response, sizeof(response), 0);
            __sync_fetch_and_add(&completed, 1);
        }
        close(sock);
    }
    
    double end = get_time_ms();
    volatile int result = completed;
    (void)result;
    return end - start;
}

// producer thread function
void* producer_thread(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    queue_t* queue = data->queue;
    
    for (int i = 0; i < data->iterations; i++) {
        pthread_mutex_lock(&queue->mutex);
        
        while (queue->count >= QUEUE_SIZE) {
            pthread_cond_wait(&queue->not_full, &queue->mutex);
        }
        
        queue->items[queue->rear] = i + data->thread_id * 1000;
        queue->rear = (queue->rear + 1) % QUEUE_SIZE;
        queue->count++;
        
        pthread_cond_signal(&queue->not_empty);
        pthread_mutex_unlock(&queue->mutex);
    }
    
    return NULL;
}

// consumer thread function
void* consumer_thread(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    queue_t* queue = data->queue;
    
    for (int i = 0; i < data->iterations; i++) {
        pthread_mutex_lock(&queue->mutex);
        
        while (queue->count <= 0) {
            pthread_cond_wait(&queue->not_empty, &queue->mutex);
        }
        
        int item = queue->items[queue->front];
        queue->front = (queue->front + 1) % QUEUE_SIZE;
        queue->count--;
        __sync_fetch_and_add(data->counter, 1);
        
        pthread_cond_signal(&queue->not_full);
        pthread_mutex_unlock(&queue->mutex);
        
        // simulate processing
        volatile int dummy = item * item;
        (void)dummy;
    }
    
    return NULL;
}

// producer-consumer queue test
double producer_consumer_test(int num_pairs, int items_per_thread) {
    double start = get_time_ms();
    
    queue_t queue = {0};
    pthread_mutex_init(&queue.mutex, NULL);
    pthread_cond_init(&queue.not_full, NULL);
    pthread_cond_init(&queue.not_empty, NULL);
    
    volatile int counter = 0;
    pthread_t producers[MAX_THREADS], consumers[MAX_THREADS];
    thread_data_t producer_data[MAX_THREADS], consumer_data[MAX_THREADS];
    
    // create producer threads
    for (int i = 0; i < num_pairs; i++) {
        producer_data[i].thread_id = i;
        producer_data[i].iterations = items_per_thread;
        producer_data[i].queue = &queue;
        producer_data[i].counter = &counter;
        pthread_create(&producers[i], NULL, producer_thread, &producer_data[i]);
    }
    
    // create consumer threads
    for (int i = 0; i < num_pairs; i++) {
        consumer_data[i].thread_id = i;
        consumer_data[i].iterations = items_per_thread;
        consumer_data[i].queue = &queue;
        consumer_data[i].counter = &counter;
        pthread_create(&consumers[i], NULL, consumer_thread, &consumer_data[i]);
    }
    
    // wait for completion
    for (int i = 0; i < num_pairs; i++) {
        pthread_join(producers[i], NULL);
        pthread_join(consumers[i], NULL);
    }
    
    pthread_mutex_destroy(&queue.mutex);
    pthread_cond_destroy(&queue.not_full);
    pthread_cond_destroy(&queue.not_empty);
    
    double end = get_time_ms();
    volatile int result = counter;
    (void)result;
    return end - start;
}

// mathematical computation function
void* math_worker(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    volatile long long sum = 0;
    
    for (int i = 0; i < data->iterations; i++) {
        // compute fibonacci-like sequence
        long long a = 0, b = 1;
        for (int j = 0; j < 35; j++) {
            long long temp = a + b;
            a = b;
            b = temp;
        }
        sum += b;
    }
    
    __sync_fetch_and_add(data->counter, (int)sum & 0xFF);
    return NULL;
}

// parallel mathematical work test  
double parallel_math_test(int num_threads, int work_per_thread) {
    double start = get_time_ms();
    
    pthread_t threads[MAX_THREADS];
    thread_data_t thread_data[MAX_THREADS];
    volatile int total = 0;
    
    for (int i = 0; i < num_threads; i++) {
        thread_data[i].thread_id = i;
        thread_data[i].iterations = work_per_thread;
        thread_data[i].counter = &total;
        pthread_create(&threads[i], NULL, math_worker, &thread_data[i]);
    }
    
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
    
    double end = get_time_ms();
    volatile int result = total;
    (void)result;
    return end - start;
}

// async file processing test
double async_file_test(int num_files) {
    double start = get_time_ms();
    
    volatile int processed = 0;
    
#pragma omp parallel for
    for (int i = 0; i < num_files; i++) {
        char filename[32];
        sprintf(filename, "/tmp/test_%d.dat", i);
        
        // create and write file
        FILE* f = fopen(filename, "w");
        if (f) {
            for (int j = 0; j < 1000; j++) {
                fprintf(f, "data_%d_%d\n", i, j);
            }
            fclose(f);
        }
        
        // read and process file
        f = fopen(filename, "r");
        if (f) {
            char buffer[64];
            int lines = 0;
            while (fgets(buffer, sizeof(buffer), f)) {
                lines++;
            }
            fclose(f);
            
            if (lines > 0) {
                __sync_fetch_and_add(&processed, 1);
            }
        }
        
        // cleanup
        unlink(filename);
    }
    
    double end = get_time_ms();
    volatile int result = processed;
    (void)result;
    return end - start;
}

// thread pool worker function
void* pool_worker(void* arg) {
    thread_data_t* data = (thread_data_t*)arg;
    
    for (int i = 0; i < data->iterations; i++) {
        // simulate varied workload
        volatile int work = 0;
        for (int j = 0; j < 10000; j++) {
            work += j * j;
        }
        __sync_fetch_and_add(data->counter, 1);
        
        // small delay to simulate real work
        usleep(100);
    }
    
    return NULL;
}

// thread pool performance test
double thread_pool_test(int pool_size, int total_tasks) {
    double start = get_time_ms();
    
    pthread_t threads[MAX_THREADS];
    thread_data_t thread_data[MAX_THREADS];
    volatile int completed = 0;
    
    int tasks_per_thread = total_tasks / pool_size;
    
    for (int i = 0; i < pool_size; i++) {
        thread_data[i].thread_id = i;
        thread_data[i].iterations = tasks_per_thread;
        thread_data[i].counter = &completed;
        pthread_create(&threads[i], NULL, pool_worker, &thread_data[i]);
    }
    
    for (int i = 0; i < pool_size; i++) {
        pthread_join(threads[i], NULL);
    }
    
    double end = get_time_ms();
    volatile int result = completed;
    (void)result;
    return end - start;
}

int main(int argc, char* argv[]) {
    int scale_factor = 1;
    if (argc > 1) {
        scale_factor = atoi(argv[1]);
        if (scale_factor <= 0) scale_factor = 1;
    }

    double total_time = 0.0;

    total_time += parallel_http_test(50 * scale_factor);
    total_time += producer_consumer_test(4, 1000 * scale_factor);
    total_time += parallel_math_test(4, 100 * scale_factor);
    total_time += async_file_test(20 * scale_factor);
    total_time += thread_pool_test(8, 500 * scale_factor);

    printf("%.3f\n", total_time);
    return 0;
}