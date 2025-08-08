using Base.Threads
using HTTP
using JSON
using Printf

# parallel http requests test using Julia's @async and @sync
function parallel_http_test(num_requests::Int)::Float64
    start_time = time_ns()
    
    successful = Threads.Atomic{Int}(0)
    
    @sync begin
        for i in 1:num_requests
            @async begin
                try
                    response = HTTP.get("http://127.0.0.1:8000/fast", connect_timeout=5, readtimeout=5)
                    if response.status == 200
                        Threads.atomic_add!(successful, 1)
                    end
                catch
                    # ignore errors for benchmark
                end
            end
        end
    end
    
    end_time = time_ns()
    _ = successful[]  # prevent optimization
    return (end_time - start_time) / 1_000_000
end

# producer-consumer queue test using Julia's channels
function producer_consumer_test(num_pairs::Int, items_per_thread::Int)::Float64
    start_time = time_ns()
    
    task_channel = Channel{Int}(1000)
    processed = Threads.Atomic{Int}(0)
    
    # create producer tasks
    producer_tasks = []
    for i in 1:num_pairs
        task = @async begin
            for j in 1:items_per_thread
                put!(task_channel, (i-1) * 1000 + j)
            end
        end
        push!(producer_tasks, task)
    end
    
    # create consumer tasks
    consumer_tasks = []
    for i in 1:num_pairs
        task = @async begin
            for j in 1:items_per_thread
                item = take!(task_channel)
                
                # simulate processing
                dummy = item * item
                
                Threads.atomic_add!(processed, 1)
            end
        end
        push!(consumer_tasks, task)
    end
    
    # wait for all tasks to complete
    for task in producer_tasks
        wait(task)
    end
    for task in consumer_tasks
        wait(task)
    end
    
    close(task_channel)
    
    end_time = time_ns()
    _ = processed[]  # prevent optimization
    return (end_time - start_time) / 1_000_000
end

# fibonacci computation
function fibonacci(n::Int)::Int64
    if n <= 1
        return Int64(n)
    end
    
    a, b = Int64(0), Int64(1)
    for i in 2:n
        a, b = b, a + b
    end
    return b
end

# parallel mathematical work test using Julia's @threads
function parallel_math_test(num_threads::Int, work_per_thread::Int)::Float64
    start_time = time_ns()
    
    total_sum = Threads.Atomic{Int64}(0)
    
    @sync begin
        for i in 1:num_threads
            @async begin
                local_sum = Int64(0)
                
                for j in 1:work_per_thread
                    local_sum += fibonacci(35)
                    
                    # additional mathematical work
                    for k in 1:1000
                        local_sum += Int64(k * k)
                    end
                end
                
                Threads.atomic_add!(total_sum, local_sum)
            end
        end
    end
    
    end_time = time_ns()
    _ = total_sum[]  # prevent optimization
    return (end_time - start_time) / 1_000_000
end

# async file processing test
function async_file_test(num_files::Int)::Float64
    start_time = time_ns()
    
    temp_dir = mktempdir(prefix="concurrency_test_")
    processed = Threads.Atomic{Int}(0)
    
    @sync begin
        for i in 1:num_files
            @async begin
                try
                    filename = joinpath(temp_dir, "test_$(i).dat")
                    
                    # write file
                    open(filename, "w") do f
                        for j in 1:1000
                            println(f, "data_$(i)_$(j)")
                        end
                    end
                    
                    # read and process file
                    lines = readlines(filename)
                    
                    # simulate processing
                    line_count = length(lines)
                    if line_count > 0
                        # process each line
                        for line in lines
                            _ = length(line)  # simulate processing
                        end
                        Threads.atomic_add!(processed, 1)
                    end
                    
                    # cleanup
                    rm(filename, force=true)
                    
                catch e
                    # ignore errors for benchmark
                end
            end
        end
    end
    
    # cleanup temp directory
    rm(temp_dir, recursive=true, force=true)
    
    end_time = time_ns()
    _ = processed[]  # prevent optimization
    return (end_time - start_time) / 1_000_000
end

# thread pool worker task
function pool_worker_task()::Int
    # simulate varied workload
    work = 0
    for j in 1:10000
        work += j * j
    end
    
    sleep(0.0001)  # 100 microseconds
    return 1
end

# thread pool performance test using Julia's @distributed
function thread_pool_test(pool_size::Int, total_tasks::Int)::Float64
    start_time = time_ns()
    
    completed = Threads.Atomic{Int}(0)
    
    # use Julia's task scheduling with limited concurrency
    @sync begin
        semaphore = Base.Semaphore(pool_size)
        
        for i in 1:total_tasks
            @async begin
                Base.acquire(semaphore)
                try
                    result = pool_worker_task()
                    Threads.atomic_add!(completed, result)
                finally
                    Base.release(semaphore)
                end
            end
        end
    end
    
    end_time = time_ns()
    _ = completed[]  # prevent optimization
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
            println(stderr, "Invalid scale factor. Using default 1.")
            scale_factor = 1
        end
    end
    
    total_time = 0.0
    
    # warm up Julia JIT compiler
    parallel_http_test(2)
    producer_consumer_test(1, 10)
    parallel_math_test(1, 5)
    async_file_test(2)
    thread_pool_test(2, 10)
    
    # actual benchmarks
    total_time += parallel_http_test(50 * scale_factor)
    total_time += producer_consumer_test(4, 1000 * scale_factor)
    total_time += parallel_math_test(4, 100 * scale_factor)
    total_time += async_file_test(20 * scale_factor)
    total_time += thread_pool_test(8, 500 * scale_factor)
    
    @printf "%.3f\n" total_time
end

main()