import sys
import time
import random
import math
import cmath
import heapq

def matrix_operations(size):
    a = [[0] * size for _ in range(size)]
    b = [[0] * size for _ in range(size)]
    c = [[0] * size for _ in range(size)]
    temp = [[0] * size for _ in range(size)]
    
    random.seed(42)
    for i in range(size):
        for j in range(size):
            a[i][j] = random.uniform(1, 10)
            b[i][j] = random.uniform(1, 10)
    
    start = time.perf_counter()
    
    # blocked matrix multiplication
    block = 32
    for ii in range(0, size, block):
        for jj in range(0, size, block):
            for kk in range(0, size, block):
                i_max = min(ii + block, size)
                j_max = min(jj + block, size)
                k_max = min(kk + block, size)
                for i in range(ii, i_max):
                    for j in range(jj, j_max):
                        for k in range(kk, k_max):
                            c[i][j] += a[i][k] * b[k][j]
    
    # matrix transpose
    for i in range(size):
        for j in range(size):
            temp[j][i] = c[i][j]
    
    # matrix operations
    scalar = 1.5
    for i in range(size):
        for j in range(size):
            c[i][j] = temp[i][j] + a[i][j] * scalar
    
    end = time.perf_counter()
    
    total = sum(c[i][i] for i in range(size))
    
    return (end - start) * 1000

def is_prime_fast(n):
    if n < 2:
        return False
    if n == 2 or n == 3:
        return True
    if n % 2 == 0 or n % 3 == 0:
        return False
    
    i = 5
    while i * i <= n:
        if n % i == 0 or n % (i + 2) == 0:
            return False
        i += 6
    return True

def factorize(n):
    factors = []
    i = 2
    while i * i <= n:
        while n % i == 0:
            factors.append(i)
            n //= i
        i += 1
    if n > 1:
        factors.append(n)
    return factors

def number_theory(limit):
    start = time.perf_counter()
    
    is_prime = [True] * (limit + 1)
    is_prime[0] = is_prime[1] = False
    
    # segmented sieve
    i = 2
    while i * i <= limit:
        if is_prime[i]:
            j = i * i
            while j <= limit:
                is_prime[j] = False
                j += i
        i += 1
    
    # primality testing and factorization
    prime_count = 0
    composite_factors = 0
    for i in range(limit - 1000, limit + 1):
        if is_prime_fast(i):
            prime_count += 1
        else:
            factors = factorize(i)
            composite_factors += len(factors)
    
    # twin prime counting
    twin_primes = 0
    for i in range(3, limit - 1):
        if is_prime[i] and is_prime[i + 2]:
            twin_primes += 1
    
    end = time.perf_counter()
    result = prime_count + composite_factors + twin_primes
    
    return (end - start) * 1000

def statistical_computing(samples):
    start = time.perf_counter()
    
    random.seed(42)
    inside_circle = 0
    values = []
    
    # monte carlo and normal distribution
    for i in range(samples):
        x = random.random()
        y = random.random()
        if x * x + y * y <= 1.0:
            inside_circle += 1
        
        # box-muller for normal distribution
        if i % 2 == 0:
            u1 = random.random()
            u2 = random.random()
            z0 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
            values.append(z0)
    
    pi_estimate = 4.0 * inside_circle / samples
    
    # statistical calculations
    mean = sum(values) / len(values)
    variance = sum((val - mean) ** 2 for val in values) / len(values)
    
    # numerical integration
    integration_samples = samples // 4
    integral_sum = 0.0
    for _ in range(integration_samples):
        x = random.random() * math.pi / 2
        integral_sum += math.sin(x)
    integral_result = (math.pi / 2) * integral_sum / integration_samples
    
    end = time.perf_counter()
    result = pi_estimate + variance + integral_result
    
    return (end - start) * 1000

def fft(data):
    n = len(data)
    if n <= 1:
        return data
    
    even = fft([data[i] for i in range(0, n, 2)])
    odd = fft([data[i] for i in range(1, n, 2)])
    
    result = [0] * n
    for i in range(n // 2):
        t = cmath.exp(-2j * cmath.pi * i / n) * odd[i]
        result[i] = even[i] + t
        result[i + n // 2] = even[i] - t
    
    return result

def ifft(data):
    n = len(data)
    conjugated = [complex(x.real, -x.imag) for x in data]
    result = fft(conjugated)
    return [complex(x.real / n, -x.imag / n) for x in result]

def signal_processing(size):
    random.seed(42)
    signal = []
    kernel = []
    
    for _ in range(size):
        real = random.uniform(-1, 1)
        imag = random.uniform(-1, 1)
        signal.append(complex(real, imag))
        kernel.append(complex(random.uniform(-1, 1), 0))
    
    start = time.perf_counter()
    
    # forward fft
    signal_fft = fft(signal[:])
    kernel_fft = fft(kernel[:])
    
    # convolution in frequency domain
    result = [signal_fft[i] * kernel_fft[i] for i in range(size)]
    
    # inverse fft
    result = ifft(result)
    
    # round trip test
    roundtrip = fft(signal[:])
    roundtrip = ifft(roundtrip)
    
    error_sum = sum(abs(roundtrip[i] - signal[i]) for i in range(size))
    
    end = time.perf_counter()
    
    total = sum(abs(val) for val in result) + error_sum
    
    return (end - start) * 1000

def heapify(arr, n, i):
    largest = i
    left = 2 * i + 1
    right = 2 * i + 2
    
    if left < n and arr[left] > arr[largest]:
        largest = left
    if right < n and arr[right] > arr[largest]:
        largest = right
    
    if largest != i:
        arr[i], arr[largest] = arr[largest], arr[i]
        heapify(arr, n, largest)

def heap_sort(arr):
    n = len(arr)
    
    for i in range(n // 2 - 1, -1, -1):
        heapify(arr, n, i)
    
    for i in range(n - 1, 0, -1):
        arr[0], arr[i] = arr[i], arr[0]
        heapify(arr, i, 0)

def data_structures(size):
    random.seed(42)
    data1 = [random.randint(1, size * 10) for _ in range(size)]
    data2 = list(range(size))
    data3 = list(range(size, 0, -1))
    
    start = time.perf_counter()
    
    # multiple sorting algorithms
    data1.sort()
    heap_sort(data2)
    data3.sort()
    
    # merge operation
    merged = []
    i = j = 0
    while i < len(data1) and j < len(data2):
        if data1[i] <= data2[j]:
            merged.append(data1[i])
            i += 1
        else:
            merged.append(data2[j])
            j += 1
    merged.extend(data1[i:])
    merged.extend(data2[j:])
    
    # binary search operations
    found_count = 0
    for _ in range(2000):
        target = random.randint(1, size * 10)
        # binary search implementation
        left, right = 0, len(data1) - 1
        while left <= right:
            mid = (left + right) // 2
            if data1[mid] == target:
                found_count += 1
                break
            elif data1[mid] < target:
                left = mid + 1
            else:
                right = mid - 1
        
        left, right = 0, len(data2) - 1
        while left <= right:
            mid = (left + right) // 2
            if data2[mid] == target:
                found_count += 1
                break
            elif data2[mid] < target:
                left = mid + 1
            else:
                right = mid - 1
    
    # heap operations
    heap = data3[:]
    heapq.heapify(heap)
    for _ in range(100):
        if heap:
            heapq.heappop(heap)
        heapq.heappush(heap, random.randint(1, size * 10))
    
    end = time.perf_counter()
    result = found_count + len(merged) + len(heap)
    
    return (end - start) * 1000

def main():
    scale_factor = 1
    
    if len(sys.argv) > 1:
        try:
            scale_factor = int(sys.argv[1])
            if scale_factor < 1 or scale_factor > 5:
                print("Scale factor must be between 1 and 5", file=sys.stderr)
                sys.exit(1)
        except ValueError:
            print(f"Invalid scale factor: {sys.argv[1]}", file=sys.stderr)
            sys.exit(1)
    
    total_time = 0
    
    total_time += matrix_operations(40 * scale_factor)
    total_time += number_theory(80000 * scale_factor)
    total_time += statistical_computing(300000 * scale_factor)
    total_time += signal_processing(256 * scale_factor)
    total_time += data_structures(30000 * scale_factor)
    
    print(f"{total_time:.3f}")

if __name__ == "__main__":
    main()