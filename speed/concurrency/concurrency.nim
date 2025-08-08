import std/[asyncdispatch, httpclient, times, os, strutils, threadpool, locks, channels]
import std/[strformat, tempfiles, random]

# parallel http requests test using async/await
proc parallelHttpTest(numRequests: int): float =
    let start = epochTime()
    var successful = 0
    
    proc makeRequest(): Future[bool] {.async.} =
        try:
            let client = newAsyncHttpClient()
            defer: client.close()
            
            let response = await client.get("http://127.0.0.1:8000/fast")
            if response.status.startsWith("200"):
                return true
        except:
            discard
        return false
    
    var futures: seq[Future[bool]]
    for i in 0 ..< numRequests:
        futures.add(makeRequest())
    
    for future in futures:
        if waitFor(future):
            inc successful
    
    let duration = epochTime() - start
    discard successful # prevent optimization
    return duration * 1000.0

# producer-consumer queue test using channels
proc producerConsumerTest(numPairs: int, itemsPerThread: int): float =
    let start = epochTime()
    var 
        taskChannel: Channel[int]
        processed = 0
        processedLock: Lock
    
    taskChannel.open()
    initLock(processedLock)
    
    proc producer(producerId: int) {.thread.} =
        for i in 0 ..< itemsPerThread:
            taskChannel.send(producerId * 1000 + i)
    
    proc consumer() {.thread.} =
        var localCount = 0
        for i in 0 ..< itemsPerThread:
            let item = taskChannel.recv()
            
            # simulate processing
            let dummy = item * item
            inc localCount
        
        withLock processedLock:
            processed += localCount
    
    var threads: seq[Thread[int]]
    newSeq(threads, numPairs * 2)
    
    # create producer threads
    for i in 0 ..< numPairs:
        createThread(threads[i], producer, i)
    
    # create consumer threads
    for i in 0 ..< numPairs:
        createThread(threads[numPairs + i], consumer)
    
    # wait for all threads to complete
    for thread in threads:
        joinThread(thread)
    
    taskChannel.close()
    deinitLock(processedLock)
    
    let duration = epochTime() - start
    discard processed # prevent optimization
    return duration * 1000.0

# fibonacci computation
proc fibonacci(n: int): int64 =
    if n <= 1:
        return n.int64
    
    var a, b = (0i64, 1i64)
    for i in 2..n:
        let temp = a + b
        a = b
        b = temp
    
    return b

# mathematical worker function
proc mathWorker(workPerThread: int): int64 =
    var localSum = 0i64
    
    for i in 0 ..< workPerThread:
        localSum += fibonacci(35)
        
        # additional mathematical work
        for k in 0 ..< 1000:
            localSum += (k * k).int64
    
    return localSum

# parallel mathematical work test using spawn
proc parallelMathTest(numThreads: int, workPerThread: int): float =
    let start = epochTime()
    
    var futures: seq[FlowVar[int64]]
    for i in 0 ..< numThreads:
        futures.add(spawn mathWorker(workPerThread))
    
    var totalSum = 0i64
    for future in futures:
        totalSum += ^future
    
    let duration = epochTime() - start
    discard totalSum # prevent optimization
    return duration * 1000.0

# async file processing test
proc processFileAsync(fileId: int, tempDir: string): Future[bool] {.async.} =
    try:
        let filename = tempDir / fmt"test_{fileId}.dat"
        
        # write file
        var content = ""
        for j in 0 ..< 1000:
            content.add(fmt"data_{fileId}_{j}" & "\n")
        
        writeFile(filename, content)
        
        # read and process file
        let fileContent = readFile(filename)
        let lineCount = fileContent.count('\n')
        
        if lineCount > 0:
            # cleanup
            removeFile(filename)
            return true
        
    except:
        discard
    
    return false

proc asyncFileTest(numFiles: int): float =
    let start = epochTime()
    let tempDir = createTempDir("concurrency_test_", "")
    
    var futures: seq[Future[bool]]
    for i in 0 ..< numFiles:
        futures.add(processFileAsync(i, tempDir))
    
    var processed = 0
    for future in futures:
        if waitFor(future):
            inc processed
    
    # cleanup temp directory
    removeDir(tempDir)
    
    let duration = epochTime() - start
    discard processed # prevent optimization
    return duration * 1000.0

# thread pool worker task
proc poolWorkerTask(): int =
    # simulate varied workload
    var work = 0
    for j in 0 ..< 10000:
        work += j * j
    
    sleep(1) # 1 millisecond (Nim's sleep is in milliseconds)
    return 1

# thread pool performance test using threadpool
proc threadPoolTest(poolSize: int, totalTasks: int): float =
    let start = epochTime()
    setMaxPoolSize(poolSize)
    
    var futures: seq[FlowVar[int]]
    for i in 0 ..< totalTasks:
        futures.add(spawn poolWorkerTask())
    
    var completed = 0
    for future in futures:
        completed += ^future
    
    let duration = epochTime() - start
    discard completed # prevent optimization
    return duration * 1000.0

proc main() =
    var scaleFactor = 1
    
    if paramCount() > 0:
        try:
            scaleFactor = parseInt(paramStr(1))
            if scaleFactor <= 0:
                scaleFactor = 1
        except:
            echo "Invalid scale factor. Using default 1."
            scaleFactor = 1
    
    var totalTime = 0.0
    
    totalTime += waitFor(parallelHttpTest(50 * scaleFactor))
    totalTime += producerConsumerTest(4, 1000 * scaleFactor)
    totalTime += parallelMathTest(4, 100 * scaleFactor)
    totalTime += waitFor(asyncFileTest(20 * scaleFactor))
    totalTime += threadPoolTest(8, 500 * scaleFactor)
    
    echo fmt"{totalTime:.3f}"

when isMainModule:
    main()