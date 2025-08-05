using Printf, Random, Base.Threads

# simple arena allocator struct
mutable struct Arena
    buffer::Vector{UInt8}
    used::Int
    
    Arena(size::Int) = new(Vector{UInt8}(undef, size), 0)
end

function allocate!(arena::Arena, size::Int)::Union{Nothing, Vector{UInt8}}
    # align to 8 bytes
    size = (size + 7) & ~7
    
    if arena.used + size > length(arena.buffer)
        return nothing
    end
    
    start_idx = arena.used + 1
    end_idx = arena.used + size
    arena.used += size
    
    return view(arena.buffer, start_idx:end_idx)
end

function reset!(arena::Arena)
    arena.used = 0
end

# allocation patterns test - sequential, random, producer-consumer
function allocation_patterns_test(iterations::Int)::Float64
    start_time = time_ns()
    
    # sequential allocation pattern
    ptrs = Vector{Vector{UInt8}}(undef, iterations)
    for i in 1:iterations
        size = 64 + ((i - 1) % 256)
        ptrs[i] = Vector{UInt8}(undef, size)
    end
    
    # clear and trigger GC
    ptrs = nothing
    GC.gc()
    
    # random allocation pattern
    Random.seed!(42)
    raw_ptrs = Vector{Vector{UInt8}}(undef, iterations)
    
    for i in 1:iterations
        size = 32 + rand(1:512)
        raw_ptrs[i] = Vector{UInt8}(undef, size)
    end
    
    # random deallocation (shuffle and clear)
    shuffle!(raw_ptrs)
    raw_ptrs = nothing
    GC.gc()
    
    end_time = time_ns()
    _ = iterations  # prevent optimization
    return (end_time - start_time) / 1_000_000
end

# worker function for gc stress test
function gc_stress_worker(thread_id::Int, iterations::Int, counter::Ref{Int})
    Random.seed!(42 + thread_id)
    local_counter = 0
    
    for i in 1:iterations
        size = 16 + rand(1:1024)
        data = Vector{UInt8}(undef, size)
        
        # simulate work
        fill!(data, UInt8(i & 0xFF))
        
        # calculate sum
        total = UInt8(0)
        for j in 1:8:length(data)
            total += data[j]
        end
        _ = total  # prevent optimization
        
        local_counter += 1
    end
    
    atomic_add!(counter, local_counter)
end

# gc stress testing with multiple threads
function gc_stress_test(num_threads::Int, iterations_per_thread::Int)::Float64
    start_time = time_ns()
    
    counter = Ref{Int}(0)
    
    @threads for i in 1:num_threads
        gc_stress_worker(i, iterations_per_thread, counter)
    end
    
    result = counter[]
    _ = result  # prevent optimization
    
    end_time = time_ns()
    return (end_time - start_time) / 1_000_000
end

# cache locality and fragmentation test
function cache_locality_test(iterations::Int)::Float64
    start_time = time_ns()
    
    # allocate small and large objects interleaved
    small_ptrs = Vector{Vector{UInt8}}(undef, iterations)
    large_ptrs = Vector{Vector{UInt8}}(undef, iterations)
    
    Random.seed!(42)
    
    # interleaved allocation pattern
    for i in 1:iterations
        small_size = 16 + rand(1:64)
        large_size = 1024 + rand(1:4096)
        
        small_array = Vector{UInt8}(undef, small_size)
        large_array = Vector{UInt8}(undef, large_size)
        
        # access pattern to test spatial locality
        fill!(small_array, UInt8(i & 0xFF))
        fill!(large_array[1:min(1024, length(large_array))], UInt8((i + 1) & 0xFF))
        
        small_ptrs[i] = small_array
        large_ptrs[i] = large_array
    end
    
    # random access pattern to stress cache
    for i in 1:(iterations ÷ 2)
        idx1 = rand(1:iterations)
        idx2 = rand(1:iterations)
        
        if idx1 <= length(small_ptrs)
            small_array = small_ptrs[idx1]
            total = UInt8(0)
            for j in 1:min(16, length(small_array))
                total += small_array[j]
            end
            _ = total
        end
        
        if idx2 <= length(large_ptrs)
            large_array = large_ptrs[idx2]
            total = UInt8(0)
            for j in 1:64:min(1024, length(large_array))
                total += large_array[j]
            end
            _ = total
        end
    end
    
    end_time = time_ns()
    return (end_time - start_time) / 1_000_000
end

# memory pool performance test
function memory_pool_test(iterations::Int)::Float64
    start_time = time_ns()
    
    # test standard allocation
    std_ptrs = Vector{Vector{UInt8}}(undef, iterations)
    for i in 1:iterations
        data = Vector{UInt8}(undef, 128)
        fill!(data, UInt8(i & 0xFF))
        std_ptrs[i] = data
    end
    
    std_ptrs = nothing
    GC.gc()
    
    # test arena allocation
    arena = Arena(iterations * 128 + 1024)
    arena_ptrs = Vector{Union{Nothing, Vector{UInt8}}}(undef, iterations)
    
    for i in 1:iterations
        ptr = allocate!(arena, 128)
        if ptr !== nothing
            fill!(ptr, UInt8(i & 0xFF))
            arena_ptrs[i] = ptr
        end
    end
    
    # batch deallocation
    reset!(arena)
    
    # test batch allocation
    for batch in 1:10
        for i in 1:(iterations ÷ 10)
            ptr = allocate!(arena, 128)
            if ptr !== nothing
                fill!(ptr, UInt8(i & 0xFF))
            end
        end
        reset!(arena)
    end
    
    end_time = time_ns()
    return (end_time - start_time) / 1_000_000
end

# memory intensive workloads test
function memory_intensive_test(large_size_mb::Int)::Float64
    start_time = time_ns()
    
    size = large_size_mb * 1024 * 1024
    
    # large object allocation
    large_array1 = Vector{UInt8}(undef, size)
    large_array2 = Vector{UInt8}(undef, size)
    
    # memory bandwidth test - sequential write
    @inbounds for i in 1:4096:size
        large_array1[i] = UInt8(i & 0xFF)
    end
    
    # memory copy operations
    copyto!(large_array2, large_array1)
    
    # memory bandwidth test - sequential read
    total = 0
    @inbounds for i in 1:4096:size
        total += Int(large_array2[i])
    end
    _ = total
    
    # memory access pattern test
    Random.seed!(42)
    for i in 1:10000
        offset = rand(1:(size - 64))
        val = large_array1[offset]
        large_array2[offset] = UInt8((Int(val) + 1) & 0xFF)
    end
    
    end_time = time_ns()
    return (end_time - start_time) / 1_000_000
end

function main()
    scale_factor = 1
    
    if length(ARGS) > 0
        try
            scale_factor = parse(Int, ARGS[1])
            if scale_factor <= 0
                scale_factor = 1
            end
        catch
            @warn "Invalid scale factor. Using default 1."
            scale_factor = 1
        end
    end
    
    total_time = 0.0
    
    # warm up Julia JIT compiler
    allocation_patterns_test(100)
    gc_stress_test(2, 100)
    cache_locality_test(100)
    memory_pool_test(100)
    memory_intensive_test(1)
    
    # actual benchmarks
    total_time += allocation_patterns_test(10000 * scale_factor)
    total_time += gc_stress_test(4, 2500 * scale_factor)
    total_time += cache_locality_test(5000 * scale_factor)
    total_time += memory_pool_test(8000 * scale_factor)
    total_time += memory_intensive_test(100 * scale_factor)
    
    @printf "%.3f\n" total_time
end

main()