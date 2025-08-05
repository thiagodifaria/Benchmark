#define _USE_MATH_DEFINES
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <string.h>
#include <stdbool.h>

#ifdef _WIN32
#include <windows.h>
#include <malloc.h>
#else
#include <sys/time.h>
#endif

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// LCG for consistent random numbers across platforms
typedef struct {
    unsigned long long state;
} rng_t;

static inline double rng_uniform(rng_t* restrict rng) {
    rng->state = rng->state * 1103515245ULL + 12345ULL;
    return ((rng->state >> 16) & 0x7fff) / 32767.0;
}

static inline double rng_normal(rng_t* restrict rng) {
    static bool has_spare = false;
    static double spare;
    
    if (has_spare) {
        has_spare = false;
        return spare;
    }
    
    has_spare = true;
    double u1 = rng_uniform(rng);
    double u2 = rng_uniform(rng);
    double magnitude = sqrt(-2.0 * log(u1));
    spare = magnitude * sin(2.0 * M_PI * u2);
    return magnitude * cos(2.0 * M_PI * u2);
}

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

// matrix operations with better cache usage
double matrix_operations(int size) {
    // align memory for better SIMD and cache performance
    double** restrict a = malloc(size * sizeof(double*));
    double** restrict b = malloc(size * sizeof(double*));
    double** restrict c = malloc(size * sizeof(double*));
    double** restrict temp = malloc(size * sizeof(double*));
    
    for (int i = 0; i < size; i++) {
#ifdef _WIN32
        a[i] = _aligned_malloc(size * sizeof(double), 64);
        b[i] = _aligned_malloc(size * sizeof(double), 64);
        c[i] = _aligned_malloc(size * sizeof(double), 64);
        temp[i] = _aligned_malloc(size * sizeof(double), 64);
        if (c[i]) memset(c[i], 0, size * sizeof(double));
#else
        a[i] = aligned_alloc(64, size * sizeof(double));
        b[i] = aligned_alloc(64, size * sizeof(double));
        c[i] = aligned_alloc(64, size * sizeof(double));
        temp[i] = aligned_alloc(64, size * sizeof(double));
        if (c[i]) memset(c[i], 0, size * sizeof(double));
#endif
        if (!a[i] || !b[i] || !c[i] || !temp[i]) {
            if (a[i]) free(a[i]);
            if (b[i]) free(b[i]);
            if (c[i]) free(c[i]);
            if (temp[i]) free(temp[i]);
            a[i] = malloc(size * sizeof(double));
            b[i] = malloc(size * sizeof(double));
            c[i] = calloc(size, sizeof(double));
            temp[i] = malloc(size * sizeof(double));
        }
    }
    
    rng_t rng = {42};
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            a[i][j] = rng_uniform(&rng) * 9.0 + 1.0;
            b[i][j] = rng_uniform(&rng) * 9.0 + 1.0;
        }
    }
    
    double start = get_time_ms();
    
    // blocked matrix multiplication with manual unrolling
    const int block = 64;  // larger block for modern CPUs
    for (int ii = 0; ii < size; ii += block) {
        for (int jj = 0; jj < size; jj += block) {
            for (int kk = 0; kk < size; kk += block) {
                int i_max = (ii + block < size) ? ii + block : size;
                int j_max = (jj + block < size) ? jj + block : size;
                int k_max = (kk + block < size) ? kk + block : size;
                
                for (int i = ii; i < i_max; i++) {
                    for (int j = jj; j < j_max; j++) {
                        register double sum = c[i][j];
                        int k = kk;
                        
                        // manual loop unrolling by 4 for better throughput
                        for (; k < k_max - 3; k += 4) {
                            sum += a[i][k] * b[k][j] +
                                   a[i][k+1] * b[k+1][j] +
                                   a[i][k+2] * b[k+2][j] +
                                   a[i][k+3] * b[k+3][j];
                        }
                        
                        // handle remaining elements
                        for (; k < k_max; k++) {
                            sum += a[i][k] * b[k][j];
                        }
                        
                        c[i][j] = sum;
                    }
                }
            }
        }
    }
    
    // matrix transpose with better cache access pattern
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            temp[j][i] = c[i][j];
        }
    }
    
    // vectorized matrix operations
    const double scalar = 1.5;
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            c[i][j] = temp[i][j] + a[i][j] * scalar;
        }
    }
    
    double end = get_time_ms();
    
    // prevent optimization
    volatile double sum = 0;
    for (int i = 0; i < size; i++) {
        sum += c[i][i];
    }
    
    // cleanup
    for (int i = 0; i < size; i++) {
#ifdef _WIN32
        _aligned_free(a[i]); _aligned_free(b[i]); _aligned_free(c[i]); _aligned_free(temp[i]);
#else
        free(a[i]); free(b[i]); free(c[i]); free(temp[i]);
#endif
    }
    free(a); free(b); free(c); free(temp);
    
    return end - start;
}

static inline bool is_prime_fast(long long n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    
    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
}

static inline int factorize(int n, int* restrict factors) {
    int count = 0;
    
    // handle factor 2 separately for optimization
    while (n % 2 == 0) {
        factors[count++] = 2;
        n /= 2;
    }
    
    // check odd factors from 3 onwards
    for (int i = 3; i * i <= n; i += 2) {
        while (n % i == 0) {
            factors[count++] = i;
            n /= i;
        }
    }
    if (n > 1) factors[count++] = n;
    return count;
}

// number theory with better sieve
double number_theory(int limit) {
    double start = get_time_ms();
    
    // use bit packing for better cache efficiency
    bool* restrict is_prime = calloc(limit + 1, sizeof(bool));
    for (int i = 2; i <= limit; i++) is_prime[i] = true;
    
    // segmented sieve
    for (int i = 2; i * i <= limit; i++) {
        if (is_prime[i]) {
            // start from i*i and increment by i
            for (int j = i * i; j <= limit; j += i) {
                is_prime[j] = false;
            }
        }
    }
    
    // primality testing and factorization with better cache usage
    int prime_count = 0;
    int composite_factors = 0;
    int* restrict factors = malloc(100 * sizeof(int));
    
    int start_range = (limit > 1000) ? limit - 1000 : 1;
    for (int i = start_range; i <= limit; i++) {
        if (is_prime_fast(i)) {
            prime_count++;
        } else {
            int factor_count = factorize(i, factors);
            composite_factors += factor_count;
        }
    }
    
    // twin prime counting - skip even numbers
    int twin_primes = 0;
    for (int i = 3; i <= limit - 2; i += 2) {
        if (is_prime[i] && is_prime[i + 2]) {
            twin_primes++;
        }
    }
    
    double end = get_time_ms();
    
    volatile int result = prime_count + composite_factors + twin_primes;
    
    free(is_prime);
    free(factors);
    
    return end - start;
}

// statistical computing
double statistical_computing(int samples) {
    double start = get_time_ms();
    
    rng_t rng = {42};
    int inside_circle = 0;
    double* restrict values = malloc(samples * sizeof(double));
    
    // monte carlo and normal distribution
    for (int i = 0; i < samples; i++) {
        double x = rng_uniform(&rng);
        double y = rng_uniform(&rng);
        if (x * x + y * y <= 1.0) {
            inside_circle++;
        }
        values[i] = rng_normal(&rng);
    }
    
    double pi_estimate = 4.0 * inside_circle / samples;
    
    // statistical calculations
    double mean = 0.0;
    for (int i = 0; i < samples; i++) {
        mean += values[i];
    }
    mean /= samples;
    
    double variance = 0.0;
    for (int i = 0; i < samples; i++) {
        double diff = values[i] - mean;
        variance += diff * diff;
    }
    variance /= samples;
    
    // numerical integration
    int integration_samples = samples / 4;
    double integral_sum = 0.0;
    for (int i = 0; i < integration_samples; i++) {
        double x = rng_uniform(&rng) * M_PI / 2;
        integral_sum += sin(x);
    }
    double integral_result = (M_PI / 2) * integral_sum / integration_samples;
    
    double end = get_time_ms();
    
    volatile double result = pi_estimate + variance + integral_result;
    
    free(values);
    
    return end - start;
}

// complex number operations
typedef struct {
    double real, imag;
} complex_t;

static inline complex_t complex_add(complex_t a, complex_t b) {
    return (complex_t){a.real + b.real, a.imag + b.imag};
}

static inline complex_t complex_sub(complex_t a, complex_t b) {
    return (complex_t){a.real - b.real, a.imag - b.imag};
}

static inline complex_t complex_mul(complex_t a, complex_t b) {
    return (complex_t){a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real};
}

static inline complex_t complex_polar(double mag, double angle) {
    return (complex_t){mag * cos(angle), mag * sin(angle)};
}

static inline double complex_abs(complex_t c) {
    return sqrt(c.real * c.real + c.imag * c.imag);
}

// FFT with better memory management
void fft(complex_t* restrict data, int n) {
    if (n <= 1) return;
    
    complex_t* restrict even = malloc((n/2) * sizeof(complex_t));
    complex_t* restrict odd = malloc((n/2) * sizeof(complex_t));
    
    // bit reversal
    for (int i = 0; i < n/2; i++) {
        even[i] = data[i*2];
        odd[i] = data[i*2+1];
    }
    
    fft(even, n/2);
    fft(odd, n/2);
    
    // butterfly computation with better cache usage
    for (int i = 0; i < n/2; i++) {
        complex_t t = complex_mul(complex_polar(1.0, -2 * M_PI * i / n), odd[i]);
        data[i] = complex_add(even[i], t);
        data[i + n/2] = complex_sub(even[i], t);
    }
    
    free(even);
    free(odd);
}

void ifft(complex_t* restrict data, int n) {
    for (int i = 0; i < n; i++) {
        data[i].imag = -data[i].imag;
    }
    fft(data, n);
    for (int i = 0; i < n; i++) {
        data[i].real /= n;
        data[i].imag = -data[i].imag / n;
    }
}

// signal processing
double signal_processing(int size) {
    complex_t* restrict signal = malloc(size * sizeof(complex_t));
    complex_t* restrict kernel = malloc(size * sizeof(complex_t));
    complex_t* restrict result = malloc(size * sizeof(complex_t));
    
    rng_t rng = {42};
    for (int i = 0; i < size; i++) {
        signal[i] = (complex_t){rng_uniform(&rng) * 2 - 1, rng_uniform(&rng) * 2 - 1};
        kernel[i] = (complex_t){rng_uniform(&rng) * 2 - 1, 0};
    }
    
    double start = get_time_ms();
    
    // prepare fft arrays - avoid unnecessary allocations
    complex_t* restrict signal_fft = malloc(size * sizeof(complex_t));
    complex_t* restrict kernel_fft = malloc(size * sizeof(complex_t));
    memcpy(signal_fft, signal, size * sizeof(complex_t));
    memcpy(kernel_fft, kernel, size * sizeof(complex_t));
    
    // forward fft
    fft(signal_fft, size);
    fft(kernel_fft, size);
    
    // convolution in frequency domain
    for (int i = 0; i < size; i++) {
        result[i] = complex_mul(signal_fft[i], kernel_fft[i]);
    }
    
    // inverse fft
    ifft(result, size);
    
    // round trip test with better error calculation
    complex_t* restrict roundtrip = malloc(size * sizeof(complex_t));
    memcpy(roundtrip, signal, size * sizeof(complex_t));
    fft(roundtrip, size);
    ifft(roundtrip, size);
    
    double error_sum = 0.0;
    for (int i = 0; i < size; i++) {
        error_sum += complex_abs(complex_sub(roundtrip[i], signal[i]));
    }
    
    double end = get_time_ms();
    
    volatile double sum = 0;
    for (int i = 0; i < size; i++) {
        sum += complex_abs(result[i]);
    }
    sum += error_sum;
    
    free(signal); free(kernel); free(result);
    free(signal_fft); free(kernel_fft); free(roundtrip);
    
    return end - start;
}

// heap operations
static inline void heapify(int* restrict arr, int n, int i) {
    int largest = i;
    int left = 2 * i + 1;
    int right = 2 * i + 2;
    
    if (left < n && arr[left] > arr[largest])
        largest = left;
    if (right < n && arr[right] > arr[largest])
        largest = right;
    
    if (largest != i) {
        int temp = arr[i];
        arr[i] = arr[largest];
        arr[largest] = temp;
        heapify(arr, n, largest);
    }
}

void heap_sort(int* restrict arr, int n) {
    // build max heap
    for (int i = n / 2 - 1; i >= 0; i--)
        heapify(arr, n, i);
    
    // extract elements
    for (int i = n - 1; i > 0; i--) {
        int temp = arr[0];
        arr[0] = arr[i];
        arr[i] = temp;
        heapify(arr, i, 0);
    }
}

int compare_ints(const void* a, const void* b) {
    return (*(int*)a - *(int*)b);
}

static inline int binary_search(int* restrict arr, int n, int target) {
    int left = 0, right = n - 1;
    while (left <= right) {
        int mid = left + (right - left) / 2;  // avoid overflow
        if (arr[mid] == target) return mid;
        if (arr[mid] < target) left = mid + 1;
        else right = mid - 1;
    }
    return -1;
}

// data structures test
double data_structures(int size) {
    int* restrict data1 = malloc(size * sizeof(int));
    int* restrict data2 = malloc(size * sizeof(int));
    int* restrict data3 = malloc(size * sizeof(int));
    
    rng_t rng = {42};
    for (int i = 0; i < size; i++) {
        data1[i] = (int)(rng_uniform(&rng) * size * 10) + 1;
        data2[i] = i;
        data3[i] = size - i;
    }
    
    double start = get_time_ms();
    
    // multiple sorting algorithms with better implementations
    qsort(data1, size, sizeof(int), compare_ints);
    heap_sort(data2, size);
    qsort(data3, size, sizeof(int), compare_ints);
    
    // merge operation
    int* restrict merged = malloc(size * 2 * sizeof(int));
    int i = 0, j = 0, k = 0;
    while (i < size && j < size) {
        if (data1[i] <= data2[j]) {
            merged[k++] = data1[i++];
        } else {
            merged[k++] = data2[j++];
        }
    }
    while (i < size) merged[k++] = data1[i++];
    while (j < size) merged[k++] = data2[j++];
    
    // binary search operations
    int found_count = 0;
    for (int i = 0; i < 2000; i++) {
        int target = (int)(rng_uniform(&rng) * size * 10) + 1;
        if (binary_search(data1, size, target) >= 0) found_count++;
        if (binary_search(data2, size, target) >= 0) found_count++;
    }
    
    double end = get_time_ms();
    
    volatile int result = found_count + merged[size] + data3[0];
    
    free(data1); free(data2); free(data3); free(merged);
    
    return end - start;
}

int main(int argc, char* argv[]) {
    int scale_factor = 1;
    
    if (argc > 1) {
        scale_factor = atoi(argv[1]);
        if (scale_factor < 1 || scale_factor > 5) {
            fprintf(stderr, "Scale factor must be between 1 and 5\n");
            return 1;
        }
    }
    
    double total_time = 0;
    
    total_time += matrix_operations(40 * scale_factor);
    total_time += number_theory(80000 * scale_factor);
    total_time += statistical_computing(300000 * scale_factor);
    total_time += signal_processing(256 * scale_factor);
    total_time += data_structures(30000 * scale_factor);
    
    printf("%.3f\n", total_time);
    
    return 0;
}