#define _USE_MATH_DEFINES
#include <iostream>
#include <vector>
#include <algorithm>
#include <cmath>
#include <random>
#include <chrono>
#include <complex>
#include <numeric>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

using namespace std;

double matrixOperations(int size) {
    vector<vector<double>> a(size, vector<double>(size));
    vector<vector<double>> b(size, vector<double>(size));
    vector<vector<double>> c(size, vector<double>(size, 0));
    vector<vector<double>> temp(size, vector<double>(size));
    
    random_device rd;
    mt19937 gen(42);
    uniform_real_distribution<> dis(1.0, 10.0);
    
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            a[i][j] = dis(gen);
            b[i][j] = dis(gen);
        }
    }
    
    auto start = chrono::high_resolution_clock::now();
    
    int block = 32;
    for (int ii = 0; ii < size; ii += block) {
        for (int jj = 0; jj < size; jj += block) {
            for (int kk = 0; kk < size; kk += block) {
                for (int i = ii; i < min(ii + block, size); i++) {
                    for (int j = jj; j < min(jj + block, size); j++) {
                        for (int k = kk; k < min(kk + block, size); k++) {
                            c[i][j] += a[i][k] * b[k][j];
                        }
                    }
                }
            }
        }
    }
    
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            temp[j][i] = c[i][j];
        }
    }
    
    double scalar = 1.5;
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            c[i][j] = temp[i][j] + a[i][j] * scalar;
        }
    }
    
    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::microseconds>(end - start);
    
    volatile double sum = 0;
    for (int i = 0; i < size; i++) {
        sum += c[i][i];
    }
    
    return duration.count() / 1000.0;
}

bool isPrimeFast(long long n) {
    if (n < 2) return false;
    if (n == 2 || n == 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    
    for (long long i = 5; i * i <= n; i += 6) {
        if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
}

vector<int> factorize(int n) {
    vector<int> factors;
    for (int i = 2; i * i <= n; i++) {
        while (n % i == 0) {
            factors.push_back(i);
            n /= i;
        }
    }
    if (n > 1) factors.push_back(n);
    return factors;
}

double numberTheory(int limit) {
    auto start = chrono::high_resolution_clock::now();
    
    vector<bool> is_prime(limit + 1, true);
    is_prime[0] = is_prime[1] = false;
    
    for (int i = 2; i * i <= limit; i++) {
        if (is_prime[i]) {
            for (int j = i * i; j <= limit; j += i) {
                is_prime[j] = false;
            }
        }
    }
    
    int prime_count = 0;
    int composite_factors = 0;
    for (int i = limit - 1000; i <= limit; i++) {
        if (isPrimeFast(i)) {
            prime_count++;
        } else {
            vector<int> factors = factorize(i);
            composite_factors += factors.size();
        }
    }
    
    int twin_primes = 0;
    for (int i = 3; i <= limit - 2; i++) {
        if (is_prime[i] && is_prime[i + 2]) {
            twin_primes++;
        }
    }
    
    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::microseconds>(end - start);
    
    volatile int result = prime_count + composite_factors + twin_primes;
    return duration.count() / 1000.0;
}

double statisticalComputing(int samples) {
    auto start = chrono::high_resolution_clock::now();
    
    random_device rd;
    mt19937 gen(42);
    uniform_real_distribution<> dis(0.0, 1.0);
    normal_distribution<> normal_dis(0.0, 1.0);
    
    int inside_circle = 0;
    vector<double> values;
    values.reserve(samples);
    
    for (int i = 0; i < samples; i++) {
        double x = dis(gen);
        double y = dis(gen);
        if (x * x + y * y <= 1.0) {
            inside_circle++;
        }
        values.push_back(normal_dis(gen));
    }
    
    double pi_estimate = 4.0 * inside_circle / samples;
    
    double mean = accumulate(values.begin(), values.end(), 0.0) / values.size();
    double variance = 0.0;
    for (double val : values) {
        variance += (val - mean) * (val - mean);
    }
    variance /= values.size();
    
    int integration_samples = samples / 4;
    double integral_sum = 0.0;
    for (int i = 0; i < integration_samples; i++) {
        double x = dis(gen) * M_PI / 2;
        integral_sum += sin(x);
    }
    double integral_result = (M_PI / 2) * integral_sum / integration_samples;
    
    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::microseconds>(end - start);
    
    volatile double result = pi_estimate + variance + integral_result;
    return duration.count() / 1000.0;
}

void fft(vector<complex<double>>& data) {
    int n = data.size();
    if (n <= 1) return;
    
    vector<complex<double>> even(n/2), odd(n/2);
    for (int i = 0; i < n/2; i++) {
        even[i] = data[i*2];
        odd[i] = data[i*2+1];
    }
    
    fft(even);
    fft(odd);
    
    for (int i = 0; i < n/2; i++) {
        complex<double> t = std::polar(1.0, -2 * M_PI * i / n) * odd[i];
        data[i] = even[i] + t;
        data[i + n/2] = even[i] - t;
    }
}

void ifft(vector<complex<double>>& data) {
    int n = data.size();
    for (auto& x : data) {
        x = conj(x);
    }
    fft(data);
    for (auto& x : data) {
        x = conj(x) / (double)n;
    }
}

double signalProcessing(int size) {
    vector<complex<double>> signal(size);
    vector<complex<double>> kernel(size);
    vector<complex<double>> result(size);
    
    random_device rd;
    mt19937 gen(42);
    uniform_real_distribution<> dis(-1.0, 1.0);
    
    for (int i = 0; i < size; i++) {
        signal[i] = complex<double>(dis(gen), dis(gen));
        kernel[i] = complex<double>(dis(gen), 0);
    }
    
    auto start = chrono::high_resolution_clock::now();
    
    vector<complex<double>> signal_fft = signal;
    vector<complex<double>> kernel_fft = kernel;
    fft(signal_fft);
    fft(kernel_fft);
    
    for (int i = 0; i < size; i++) {
        result[i] = signal_fft[i] * kernel_fft[i];
    }
    
    ifft(result);
    
    vector<complex<double>> roundtrip = signal;
    fft(roundtrip);
    ifft(roundtrip);
    
    double error = 0.0;
    for (int i = 0; i < size; i++) {
        error += abs(roundtrip[i] - signal[i]);
    }
    
    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::microseconds>(end - start);
    
    volatile double sum = 0;
    for (const auto& val : result) {
        sum += abs(val);
    }
    sum += error;
    
    return duration.count() / 1000.0;
}

void heapify(vector<int>& arr, int n, int i) {
    int largest = i;
    int left = 2 * i + 1;
    int right = 2 * i + 2;
    
    if (left < n && arr[left] > arr[largest])
        largest = left;
    if (right < n && arr[right] > arr[largest])
        largest = right;
    
    if (largest != i) {
        swap(arr[i], arr[largest]);
        heapify(arr, n, largest);
    }
}

void heapSort(vector<int>& arr) {
    int n = arr.size();
    
    for (int i = n / 2 - 1; i >= 0; i--)
        heapify(arr, n, i);
    
    for (int i = n - 1; i > 0; i--) {
        swap(arr[0], arr[i]);
        heapify(arr, i, 0);
    }
}

double dataStructures(int size) {
    vector<int> data1(size), data2(size), data3(size);
    
    random_device rd;
    mt19937 gen(42);
    uniform_int_distribution<> dis(1, size * 10);
    
    for (int i = 0; i < size; i++) {
        data1[i] = dis(gen);
        data2[i] = i;
        data3[i] = size - i;
    }
    
    auto start = chrono::high_resolution_clock::now();
    
    sort(data1.begin(), data1.end());
    heapSort(data2);
    stable_sort(data3.begin(), data3.end());
    
    vector<int> merged(size * 2);
    merge(data1.begin(), data1.end(), data2.begin(), data2.end(), merged.begin());
    
    int found_count = 0;
    for (int i = 0; i < 2000; i++) {
        int target = dis(gen);
        if (binary_search(data1.begin(), data1.end(), target)) found_count++;
        if (binary_search(data2.begin(), data2.end(), target)) found_count++;
    }
    
    make_heap(data3.begin(), data3.end());
    for (int i = 0; i < 100; i++) {
        pop_heap(data3.begin(), data3.end());
        data3.pop_back();
        data3.push_back(dis(gen));
        push_heap(data3.begin(), data3.end());
    }
    
    auto end = chrono::high_resolution_clock::now();
    auto duration = chrono::duration_cast<chrono::microseconds>(end - start);
    
    volatile int result = found_count + merged[size] + data3.size();
    return duration.count() / 1000.0;
}

int main(int argc, char* argv[]) {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);
    
    int scale_factor = 1;
    
    if (argc > 1) {
        try {
            scale_factor = stoi(argv[1]);
            if (scale_factor < 1 || scale_factor > 5) {
                cerr << "Scale factor must be between 1 and 5\n";
                return 1;
            }
        } catch (const exception& e) {
            cerr << "Invalid scale factor: " << argv[1] << '\n';
            return 1;
        }
    }
    
    double total_time = 0;
    
    total_time += matrixOperations(40 * scale_factor);
    total_time += numberTheory(80000 * scale_factor);
    total_time += statisticalComputing(300000 * scale_factor);
    total_time += signalProcessing(256 * scale_factor);
    total_time += dataStructures(30000 * scale_factor);
    
    cout << fixed;
    cout.precision(3);
    cout << total_time << '\n';
    
    return 0;
}