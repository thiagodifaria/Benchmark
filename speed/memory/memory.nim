import std/[times, os, strutils, locks]

# simple arena allocator type
type Arena = object
  buffer: seq[byte]
  used: int

proc newArena(size: int): Arena =
  result.buffer = newSeq[byte](size)
  result.used = 0

proc allocate(arena: var Arena, size: int): ptr UncheckedArray[byte] =
  # align to 8 bytes
  let alignedSize = (size + 7) and not 7
  
  if arena.used + alignedSize > arena.buffer.len:
    return nil
  
  result = cast[ptr UncheckedArray[byte]](addr arena.buffer[arena.used])
  arena.used += alignedSize

proc reset(arena: var Arena) =
  arena.used = 0

# get time in milliseconds
proc getTimeMs(): float =
  result = epochTime() * 1000.0

# simple xorshift rng
type XorShift64 = object
  state: uint64

proc newXorShift64(seed: uint64): XorShift64 =
  result.state = seed

proc next(rng: var XorShift64): uint64 =
  rng.state = rng.state xor (rng.state shl 13)
  rng.state = rng.state xor (rng.state shr 7)
  rng.state = rng.state xor (rng.state shl 17)
  result = rng.state

# allocation patterns test - sequential, random, producer-consumer
proc allocationPatternsTest(iterations: int): float =
  let startTime = getTimeMs()
  
  # sequential allocation pattern
  var ptrs = newSeq[seq[byte]](iterations)
  for i in 0..<iterations:
    let size = 64 + (i mod 256)
    ptrs[i] = newSeq[byte](size)
  
  ptrs.setLen(0)
  GC_fullCollect()
  
  # random allocation pattern
  var rng = newXorShift64(42)
  var rawPtrs = newSeq[seq[byte]](iterations)
  
  for i in 0..<iterations:
    let size = 32 + int(rng.next() mod 512)
    rawPtrs[i] = newSeq[byte](size)
  
  # random deallocation (shuffle and clear)
  for i in countdown(rawPtrs.high, 1):
    let j = int(rng.next() mod (i + 1).uint64)
    swap(rawPtrs[i], rawPtrs[j])
  rawPtrs.setLen(0)
  GC_fullCollect()
  
  let finishTime = getTimeMs()
  discard iterations  # prevent optimization
  return finishTime - startTime

# thread data for gc stress test
type ThreadData = object
  threadId: int
  iterations: int
  counter: ptr int
  lock: ptr Lock

proc gcStressWorker(data: ThreadData) {.thread.} =
  var rng = newXorShift64(42.uint64 + data.threadId.uint64)
  
  for i in 0..<data.iterations:
    let size = 16 + int(rng.next() mod 1024)
    var buffer = newSeq[byte](size)
    
    # simulate work
    for j in 0..<size:
      buffer[j] = byte(i and 0xFF)
    
    # calculate sum
    var sum: byte = 0
    for j in countup(0, size - 1, 8):
      sum += buffer[j]
    discard sum  # prevent optimization
    
    acquire(data.lock[])
    inc(data.counter[])
    release(data.lock[])

# gc stress testing with multiple threads
proc gcStressTest(numThreads: int, iterationsPerThread: int): float =
  let startTime = getTimeMs()
  
  var counter = 0
  var lock: Lock
  initLock(lock)
  
  var threads = newSeq[Thread[ThreadData]](numThreads)
  var threadData = newSeq[ThreadData](numThreads)
  
  for i in 0..<numThreads:
    threadData[i] = ThreadData(
      threadId: i,
      iterations: iterationsPerThread,
      counter: addr counter,
      lock: addr lock
    )
    createThread(threads[i], gcStressWorker, threadData[i])
  
  for i in 0..<numThreads:
    joinThread(threads[i])
  
  deinitLock(lock)
  
  let threadResult = counter
  discard threadResult  # prevent optimization
  
  let finishTime = getTimeMs()
  return finishTime - startTime

# cache locality and fragmentation test
proc cacheLocalityTest(iterations: int): float =
  let startTime = getTimeMs()
  
  # allocate small and large objects interleaved
  var smallPtrs = newSeq[seq[byte]](iterations)
  var largePtrs = newSeq[seq[byte]](iterations)
  
  var rng = newXorShift64(42)
  
  # interleaved allocation pattern
  for i in 0..<iterations:
    let smallSize = 16 + int(rng.next() mod 64)
    let largeSize = 1024 + int(rng.next() mod 4096)
    
    smallPtrs[i] = newSeq[byte](smallSize)
    largePtrs[i] = newSeq[byte](largeSize)
    
    # access pattern to test spatial locality
    for j in 0..<smallPtrs[i].len:
      smallPtrs[i][j] = byte(i and 0xFF)
    for j in 0..<min(1024, largePtrs[i].len):
      largePtrs[i][j] = byte((i + 1) and 0xFF)
  
  # random access pattern to stress cache
  for i in 0..<(iterations div 2):
    let idx1 = int(rng.next() mod iterations.uint64)
    let idx2 = int(rng.next() mod iterations.uint64)
    
    if idx1 < smallPtrs.len:
      var sum: byte = 0
      for j in 0..<min(16, smallPtrs[idx1].len):
        sum += smallPtrs[idx1][j]
      discard sum
    
    if idx2 < largePtrs.len:
      var sum: byte = 0
      for j in countup(0, min(1024, largePtrs[idx2].len) - 1, 64):
        sum += largePtrs[idx2][j]
      discard sum
  
  let finishTime = getTimeMs()
  return finishTime - startTime

# memory pool performance test
proc memoryPoolTest(iterations: int): float =
  let startTime = getTimeMs()
  
  # test standard allocation
  var stdPtrs = newSeq[seq[byte]](iterations)
  for i in 0..<iterations:
    stdPtrs[i] = newSeq[byte](128)
    for j in 0..<128:
      stdPtrs[i][j] = byte(i and 0xFF)
  
  stdPtrs.setLen(0)
  GC_fullCollect()
  
  # test arena allocation
  var arena = newArena(iterations * 128 + 1024)
  var arenaPtrs = newSeq[ptr UncheckedArray[byte]](iterations)
  
  for i in 0..<iterations:
    let p = arena.allocate(128)
    if p != nil:
      for j in 0..<128:
        p[j] = byte(i and 0xFF)
      arenaPtrs[i] = p
  
  # batch deallocation
  arena.reset()
  
  # test batch allocation
  for batch in 0..<10:
    for i in 0..<(iterations div 10):
      let p = arena.allocate(128)
      if p != nil:
        for j in 0..<128:
          p[j] = byte(i and 0xFF)
    arena.reset()
  
  let finishTime = getTimeMs()
  return finishTime - startTime

# memory intensive workloads test
proc memoryIntensiveTest(largeSizeMb: int): float =
  let startTime = getTimeMs()
  
  let size = largeSizeMb * 1024 * 1024
  
  # large object allocation
  var largeArray1 = newSeq[byte](size)
  var largeArray2 = newSeq[byte](size)
  
  # memory bandwidth test - sequential write
  for i in countup(0, size - 1, 4096):
    largeArray1[i] = byte(i and 0xFF)
  
  # memory copy operations
  for i in 0..<size:
    largeArray2[i] = largeArray1[i]
  
  # memory bandwidth test - sequential read
  var sum: int64 = 0
  for i in countup(0, size - 1, 4096):
    sum += largeArray2[i].int64
  discard sum
  
  # memory access pattern test
  var rng = newXorShift64(42)
  for i in 0..<10000:
    let offset = int(rng.next() mod (size - 64).uint64)
    let val = largeArray1[offset]
    largeArray2[offset] = byte((val.int + 1) and 0xFF)
  
  let finishTime = getTimeMs()
  return finishTime - startTime

proc main() =
  var scaleFactor = 1
  
  if paramCount() > 0:
    try:
      scaleFactor = parseInt(paramStr(1))
      if scaleFactor <= 0:
        scaleFactor = 1
    except ValueError:
      echo "Invalid scale factor. Using default 1."
      scaleFactor = 1
  
  var totalTime = 0.0
  
  totalTime += allocationPatternsTest(10000 * scaleFactor)
  totalTime += gcStressTest(4, 2500 * scaleFactor)
  totalTime += cacheLocalityTest(5000 * scaleFactor)
  totalTime += memoryPoolTest(8000 * scaleFactor)
  totalTime += memoryIntensiveTest(100 * scaleFactor)
  
  echo totalTime.formatFloat(ffDecimal, 3)

when isMainModule:
  main()