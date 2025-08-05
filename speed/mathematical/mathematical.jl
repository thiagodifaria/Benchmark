using Random, LinearAlgebra, FFTW

# FFTW threading - use system default unless Windows causes issues
# Comment out the line below if you get segfaults on Windows
# FFTW.set_num_threads(1)

# If you need to disable FFTW threading due to crashes, uncomment this:
# FFTW.set_num_threads(1)

function matrix_operations(size::Int)::Float64
    Random.seed!(42)
    
    a = rand(Float64, size, size) .* 9.0 .+ 1.0
    b = rand(Float64, size, size) .* 9.0 .+ 1.0
    c = zeros(Float64, size, size)
    
    start_time = time_ns()
    
    # blocked matrix multiplication for cache efficiency
    block = 32
    for ii in 1:block:size
        for jj in 1:block:size
            for kk in 1:block:size
                i_end = min(ii + block - 1, size)
                j_end = min(jj + block - 1, size)
                k_end = min(kk + block - 1, size)
                
                @inbounds for i in ii:i_end
                    for j in jj:j_end
                        for k in kk:k_end
                            c[i, j] += a[i, k] * b[k, j]
                        end
                    end
                end
            end
        end
    end
    
    # matrix transpose
    temp = transpose(c)
    
    # matrix operations
    scalar = 1.5
    @inbounds for i in 1:size
        for j in 1:size
            c[i, j] = temp[i, j] + a[i, j] * scalar
        end
    end
    
    end_time = time_ns()
    
    # prevent optimization
    sum_diagonal = sum(@inbounds c[i, i] for i in 1:size)
    
    return (end_time - start_time) / 1_000_000
end

function is_prime_fast(n::Int64)::Bool
    if n < 2 return false end
    if n == 2 || n == 3 return true end
    if n % 2 == 0 || n % 3 == 0 return false end
    
    i = 5
    while i * i <= n
        if n % i == 0 || n % (i + 2) == 0
            return false
        end
        i += 6
    end
    return true
end

function factorize(n::Int)::Vector{Int}
    factors = Int[]
    i = 2
    while i * i <= n
        while n % i == 0
            push!(factors, i)
            n ÷= i
        end
        i += 1
    end
    if n > 1
        push!(factors, n)
    end
    return factors
end

function number_theory(limit::Int)::Float64
    start_time = time_ns()
    
    is_prime = trues(limit + 1)
    is_prime[1] = false
    if limit >= 2
        is_prime[2] = true
    end
    
    # segmented sieve - skip even numbers for efficiency
    i = 3
    while i * i <= limit
        if is_prime[i]
            j = i * i
            while j <= limit
                is_prime[j] = false
                j += i
            end
        end
        i += 2
    end
    
    # primality testing and factorization
    prime_count = 0
    composite_factors = 0
    
    start_range = max(1, limit - 1000)
    for i in start_range:limit
        if is_prime_fast(Int64(i))
            prime_count += 1
        else
            factors = factorize(i)
            composite_factors += length(factors)
        end
    end
    
    # twin prime counting  
    twin_primes = 0
    for i in 3:(limit-2)
        if is_prime[i] && is_prime[i + 2]
            twin_primes += 1
        end
    end
    
    end_time = time_ns()
    
    # prevent optimization
    result = prime_count + composite_factors + twin_primes
    
    return (end_time - start_time) / 1_000_000
end

function statistical_computing(samples::Int)::Float64
    start_time = time_ns()
    
    Random.seed!(42)
    
    # pre-allocate arrays for better performance
    inside_circle = 0
    values = Vector{Float64}(undef, samples)
    
    @inbounds for i in 1:samples
        x = rand()
        y = rand()
        if x^2 + y^2 <= 1.0
            inside_circle += 1
        end
        values[i] = randn()
    end
    
    pi_estimate = 4.0 * inside_circle / samples
    
    # statistical calculations - vectorized where possible
    mean_val = sum(values) / length(values)
    variance = sum((v - mean_val)^2 for v in values) / length(values)
    
    # numerical integration of sin(x) from 0 to π/2
    integration_samples = samples ÷ 4
    integral_sum = 0.0
    @inbounds for i in 1:integration_samples
        x = rand() * π / 2
        integral_sum += sin(x)
    end
    integral_result = (π / 2) * integral_sum / integration_samples
    
    end_time = time_ns()
    
    # prevent optimization
    result = pi_estimate + variance + integral_result
    
    return (end_time - start_time) / 1_000_000
end

function signal_processing(size::Int)::Float64
    Random.seed!(42)
    
    # create test signals with explicit types
    signal = Vector{ComplexF64}(undef, size)
    kernel = Vector{ComplexF64}(undef, size)
    
    @inbounds for i in 1:size
        signal[i] = complex(rand() * 2.0 - 1.0, rand() * 2.0 - 1.0)
        kernel[i] = complex(rand() * 2.0 - 1.0, 0.0)
    end
    
    start_time = time_ns()
    
    # forward fft - this should now use multiple threads if available
    signal_fft = fft(signal)
    kernel_fft = fft(kernel)
    
    # convolution in frequency domain
    result = signal_fft .* kernel_fft
    
    # inverse fft
    result = ifft(result)
    
    # round trip test for accuracy
    roundtrip = ifft(fft(signal))
    error_sum = sum(abs(roundtrip[i] - signal[i]) for i in 1:size)
    
    end_time = time_ns()
    
    # prevent optimization
    total_sum = sum(abs(val) for val in result) + error_sum
    
    return (end_time - start_time) / 1_000_000
end

function heapify!(arr::Vector{Int}, n::Int, i::Int)
    largest = i
    left = 2 * i
    right = 2 * i + 1
    
    if left <= n && arr[left] > arr[largest]
        largest = left
    end
    if right <= n && arr[right] > arr[largest]
        largest = right
    end
    
    if largest != i
        arr[i], arr[largest] = arr[largest], arr[i]
        heapify!(arr, n, largest)
    end
end

function heap_sort!(arr::Vector{Int})
    n = length(arr)
    
    # build heap
    for i in n÷2:-1:1
        heapify!(arr, n, i)
    end
    
    # extract elements
    for i in n:-1:2
        arr[1], arr[i] = arr[i], arr[1]
        heapify!(arr, i-1, 1)
    end
end

function data_structures(size::Int)::Float64
    Random.seed!(42)
    
    data1 = rand(1:(size*10), size)
    data2 = collect(1:size)
    data3 = collect(size:-1:1)
    
    start_time = time_ns()
    
    # multiple sorting algorithms
    sort!(data1)
    heap_sort!(data2)
    sort!(data3)
    
    # merge operation - more efficient implementation
    merged = Vector{Int}(undef, size * 2)
    i, j, k = 1, 1, 1
    @inbounds while i <= size && j <= size
        if data1[i] <= data2[j]
            merged[k] = data1[i]
            i += 1
        else
            merged[k] = data2[j]
            j += 1
        end
        k += 1
    end
    @inbounds while i <= size
        merged[k] = data1[i]
        i += 1
        k += 1
    end
    @inbounds while j <= size
        merged[k] = data2[j]
        j += 1
        k += 1
    end
    
    # binary search operations
    found_count = 0
    @inbounds for _ in 1:2000
        target = rand(1:(size*10))
        if !isempty(searchsorted(data1, target))
            found_count += 1
        end
        if !isempty(searchsorted(data2, target))
            found_count += 1
        end
    end
    
    end_time = time_ns()
    
    # prevent optimization
    result = found_count + merged[size] + length(data3)
    
    return (end_time - start_time) / 1_000_000
end

function main()
    scale_factor = 1
    
    if length(ARGS) > 0
        try
            scale_factor = parse(Int, ARGS[1])
            if scale_factor < 1 || scale_factor > 5
                println(stderr, "Scale factor must be between 1 and 5")
                exit(1)
            end
        catch
            println(stderr, "Invalid scale factor: $(ARGS[1])")
            exit(1)
        end
    end
    
    total_time = 0.0
    
    # warm up Julia JIT compiler to avoid compilation overhead
    matrix_operations(10)
    number_theory(1000)
    statistical_computing(1000)
    signal_processing(64)
    data_structures(100)
    
    # actual benchmarks
    total_time += matrix_operations(40 * scale_factor)
    total_time += number_theory(80000 * scale_factor)
    total_time += statistical_computing(300000 * scale_factor)
    total_time += signal_processing(256 * scale_factor)
    total_time += data_structures(30000 * scale_factor)
    
    @printf "%.3f\n" total_time
end

# run main function
main()