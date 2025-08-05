using Printf
using Random
using Mmap
using CSV
import JSON

# sequential text read reading a file line-by-line to count words
function sequential_read_test(filename::String)::Float64
    start_time = time_ns()
    word_count = 0
    try
        # use open() with do block for automatic file closing
        open(filename, "r") do file
            for line in eachline(file)
                word_count += length(split(line))
            end
        end
    catch e
        if isa(e, SystemError)
            @error "error: could not read file -> $filename"
            return 0.0
        end
        rethrow()
    end
    
    end_time = time_ns()
    # keep the result alive
    _ = word_count
    return (end_time - start_time) / 1_000_000
end

# random access read jump around in a binary file
function random_access_test(filename::String, num_accesses::Int)::Float64
    start_time = time_ns()
    total_bytes_read = 0
    try
        open(filename, "r") do f
            file_size = filesize(filename)
            if file_size < 4096
                @error "error: binary file too small -> $filename"
                return 0.0
            end

            # keep it predictable
            rng = MersenneTwister(42)
            buffer = Vector{UInt8}(undef, 4096)
            
            for _ in 1:num_accesses
                offset = rand(rng, 0:(file_size - 4096))
                seek(f, offset)
                bytes_read = readbytes!(f, buffer)
                total_bytes_read += bytes_read
            end
        end
    catch e
        if isa(e, SystemError)
            @error "error: could not read file -> $filename"
            return 0.0
        end
        rethrow()
    end
    
    end_time = time_ns()
    _ = total_bytes_read
    return (end_time - start_time) / 1_000_000
end

# memory-mapped read using the mmap standard library
function memory_map_test(filename::String)::Float64
    start_time = time_ns()
    word_count = 0
    try
        # mmap gives us a byte vector we can slice and dice directly
        open(filename, "r") do file
            data = Mmap.mmap(file)
            # convert to string and split - Julia handles this efficiently
            content = String(data)
            word_count = length(split(content))
        end
        # julia handles unmapping automatically when 'data' goes out of scope
    catch e
        if isa(e, SystemError)
            @error "error: could not map file -> $filename"
            return 0.0
        end
        rethrow()
    end
    
    end_time = time_ns()
    _ = word_count
    return (end_time - start_time) / 1_000_000
end

# csv read and process using the csv.jl package
function csv_read_and_process_test(filename::String)::Float64
    start_time = time_ns()
    price_sum = 0.0
    filter_count = 0
    try
        # CSV.File is optimized for performance
        df = CSV.File(filename)
        for row in df
            # use getproperty for better performance than get()
            price_sum += getproperty(row, :price, 0.0)
            if getproperty(row, :category, "") == "Electronics"
                filter_count += 1
            end
        end
    catch e
        if isa(e, ArgumentError) || isa(e, SystemError)
            @error "error: could not read csv -> $filename"
            return 0.0
        end
        rethrow()
    end

    end_time = time_ns()
    _ = price_sum + filter_count
    return (end_time - start_time) / 1_000_000
end

# generate and write a bunch of records to a csv file
function csv_write_test(filename::String, num_records::Int)::Float64
    start_time = time_ns()
    
    # pre-build the data for better performance
    data = (
        id=1:num_records, 
        product_name=["Product-$(i)" for i in 1:num_records], 
        price=[i * 1.5 for i in 1:num_records], 
        category=["Category-$(i % 10)" for i in 1:num_records]
    )
    
    try
        CSV.write(filename, data)
    catch e
        @error "error: could not write csv -> $filename"
        return 0.0
    end
    
    end_time = time_ns()
    return (end_time - start_time) / 1_000_000
end

# json dom read and process using json.jl
function json_dom_read_and_process_test(filename::String)::Float64
    start_time = time_ns()
    user_id = ""
    try
        data = JSON.parsefile(filename)
        # navigate the dictionary to get what we want
        if haskey(data, "metadata") && haskey(data["metadata"], "user_id")
            user_id = data["metadata"]["user_id"]
        end
    catch e
        if isa(e, SystemError)
            @error "error: could not read json -> $filename"
            return 0.0
        end
        rethrow()
    end
    
    end_time = time_ns()
    _ = length(user_id)
    return (end_time - start_time) / 1_000_000
end

# json streaming read for huge files
# assumes json lines format (.jsonl)
function json_stream_read_and_process_test(filename::String)::Float64
    start_time = time_ns()
    total = 0.0
    try
        open(filename, "r") do f
            for line in eachline(f)
                if !isempty(line)
                    try
                        obj = JSON.parse(line)
                        if haskey(obj, "price")
                            total += obj["price"]
                        end
                    catch
                        # just skip bad lines
                        continue
                    end
                end
            end
        end
    catch e
        if isa(e, SystemError)
            @error "error: could not stream json -> $filename"
            return 0.0
        end
        rethrow()
    end

    end_time = time_ns()
    _ = total
    return (end_time - start_time) / 1_000_000
end

# build a big julia dict and dump it to a json file
function json_write_test(filename::String, num_records::Int)::Float64
    start_time = time_ns()
    
    # pre-allocate for better performance
    items = Vector{Dict{String, Any}}(undef, num_records)
    for i in 1:num_records
        items[i] = Dict{String, Any}(
            "id" => i,
            "name" => "Item $i",
            "attributes" => Dict{String, Any}("active" => true, "value" => i * 3.14)
        )
    end
    
    data = Dict{String, Any}(
        "metadata" => Dict{String, Any}("record_count" => num_records),
        "items" => items
    )
    
    try
        open(filename, "w") do f
            # the third argument 0 means no indentation for max speed
            JSON.print(f, data, 0)
        end
    catch e
        @error "error: could not write json -> $filename"
        return 0.0
    end
    
    end_time = time_ns()
    return (end_time - start_time) / 1_000_000
end

# helper function to fix haskey/getproperty issues
function getproperty(row, key::Symbol, default)
    try
        return getproperty(row, key)
    catch
        return default
    end
end

# main execution logic
function main()
    scale_factor = 1
    if length(ARGS) > 0
        try
            scale_factor = parse(Int, ARGS[1])
        catch
            @warn "invalid scale factor, using default 1"
        end
    end

    text_file = "data.txt"
    bin_file = "data.bin"
    csv_read_file = "data.csv"
    csv_write_file = "output.csv"
    json_dom_file = "data.json"
    json_stream_file = "data_large.jsonl"
    json_write_file = "output.json"

    random_accesses = 1000 * scale_factor
    csv_write_records = 100000 * scale_factor
    json_write_records = 50000 * scale_factor

    total_time = 0.0

    total_time += sequential_read_test(text_file)
    total_time += random_access_test(bin_file, random_accesses)
    total_time += memory_map_test(text_file)
    total_time += csv_read_and_process_test(csv_read_file)
    total_time += csv_write_test(csv_write_file, csv_write_records)
    total_time += json_dom_read_and_process_test(json_dom_file)
    total_time += json_stream_read_and_process_test(json_stream_file)
    total_time += json_write_test(json_write_file, json_write_records)

    @printf "%.3f\n" total_time
end

main()