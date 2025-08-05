import times, math, random, algorithm, strutils, os, strformat

# matrix operations test
proc matrixOperations(size: int): float =
    var 
        a = newSeq[seq[float64]](size)
        b = newSeq[seq[float64]](size)
        c = newSeq[seq[float64]](size)
        temp = newSeq[seq[float64]](size)
    
    # pre-allocate all arrays
    for i in 0..<size:
        a[i] = newSeq[float64](size)
        b[i] = newSeq[float64](size)
        c[i] = newSeq[float64](size)
        temp[i] = newSeq[float64](size)
    
    randomize(42)
    for i in 0..<size:
        for j in 0..<size:
            a[i][j] = rand(9.0) + 1.0
            b[i][j] = rand(9.0) + 1.0
            c[i][j] = 0.0
    
    let startTime = epochTime()
    
    # blocked matrix multiplication - optimized for modern CPUs
    const blockSize = 64  # larger block for better cache usage
    var ii = 0
    while ii < size:
        var jj = 0
        while jj < size:
            var kk = 0
            while kk < size:
                let 
                    iMax = min(ii + blockSize, size)
                    jMax = min(jj + blockSize, size)
                    kMax = min(kk + blockSize, size)
                
                # manual loop unrolling for better performance
                for i in ii..<iMax:
                    for j in jj..<jMax:
                        var accumulator = c[i][j]
                        var k = kk
                        # unroll inner loop by 4
                        while k < kMax - 3:
                            accumulator += a[i][k] * b[k][j] +
                                          a[i][k+1] * b[k+1][j] +
                                          a[i][k+2] * b[k+2][j] +
                                          a[i][k+3] * b[k+3][j]
                            k += 4
                        # handle remaining elements
                        while k < kMax:
                            accumulator += a[i][k] * b[k][j]
                            k += 1
                        c[i][j] = accumulator
                kk += blockSize
            jj += blockSize
        ii += blockSize
    
    # matrix transpose
    for i in 0..<size:
        for j in 0..<size:
            temp[j][i] = c[i][j]
    
    # matrix operations
    const scalar = 1.5
    for i in 0..<size:
        for j in 0..<size:
            c[i][j] = temp[i][j] + a[i][j] * scalar
    
    let endTime = epochTime()
    
    # prevent optimization
    var sum = 0.0
    for i in 0..<size:
        sum += c[i][i]
    
    result = (endTime - startTime) * 1000.0

proc isPrimeFast(n: int64): bool =
    if n < 2: return false
    if n == 2 or n == 3: return true
    if n mod 2 == 0 or n mod 3 == 0: return false
    
    var i: int64 = 5
    while i * i <= n:
        if n mod i == 0 or n mod (i + 2) == 0:
            return false
        i += 6
    result = true

proc factorize(n: var int): seq[int] =
    result = newSeqOfCap[int](32)
    
    # handle factor 2 separately for optimization
    while n mod 2 == 0:
        result.add(2)
        n = n div 2
    
    # check odd factors from 3 onwards
    var i = 3
    while i * i <= n:
        while n mod i == 0:
            result.add(i)
            n = n div i
        i += 2  # skip even numbers
    
    if n > 1:
        result.add(n)

proc numberTheory(limit: int): float =
    let startTime = epochTime()
    
    # optimized sieve
    var isPrime = newSeq[bool](limit + 1)
    for i in 2..limit:
        isPrime[i] = true
    
    # segmented sieve - skip even numbers
    var i = 2
    while i * i <= limit:
        if isPrime[i]:
            var j = i * i
            while j <= limit:
                isPrime[j] = false
                j += i
        if i == 2:
            i = 3
        else:
            i += 2  # skip even numbers after 2
    
    # primality testing and factorization
    var 
        primeCount = 0
        compositeFactors = 0
    
    let startRange = max(1, limit - 1000)
    
    for i in startRange..limit:
        if isPrimeFast(i.int64):
            inc primeCount
        else:
            var n = i
            let factors = factorize(n)
            compositeFactors += factors.len
    
    # twin prime counting - optimized
    var twinPrimes = 0
    for i in 3..(limit-2):
        if isPrime[i] and isPrime[i + 2]:
            inc twinPrimes
    
    let endTime = epochTime()
    
    # prevent optimization
    discard primeCount + compositeFactors + twinPrimes
    
    result = (endTime - startTime) * 1000.0

proc statisticalComputing(samples: int): float =
    let startTime = epochTime()
    
    randomize(42)
    var 
        insideCircle = 0
        values = newSeqOfCap[float64](samples)
    
    # monte carlo and normal distribution - optimized loop
    for i in 0..<samples:
        let 
            x = rand(1.0)
            y = rand(1.0)
        if x * x + y * y <= 1.0:
            inc insideCircle
        
        # box-muller transformation - generate both values when possible
        if i mod 2 == 0 and i + 1 < samples:
            let 
                u1 = rand(1.0)
                u2 = rand(1.0)
                magnitude = sqrt(-2.0 * ln(u1))
                z0 = magnitude * cos(2.0 * PI * u2)
                z1 = magnitude * sin(2.0 * PI * u2)
            values.add(z0)
            if values.len < samples:
                values.add(z1)
        elif values.len < samples:
            let 
                u1 = rand(1.0)
                u2 = rand(1.0)
                z0 = sqrt(-2.0 * ln(u1)) * cos(2.0 * PI * u2)
            values.add(z0)
    
    let piEstimate = 4.0 * insideCircle.float / samples.float
    
    # statistical calculations - single pass for mean and variance
    var total = 0.0
    for val in values:
        total += val
    let mean = total / values.len.float
    
    var variance = 0.0
    for val in values:
        let diff = val - mean
        variance += diff * diff
    variance /= values.len.float
    
    # numerical integration
    let integrationSamples = samples div 4
    var integralSum = 0.0
    for i in 0..<integrationSamples:
        let x = rand(1.0) * PI / 2
        integralSum += sin(x)
    let integralResult = (PI / 2) * integralSum / integrationSamples.float
    
    let endTime = epochTime()
    
    # prevent optimization
    discard piEstimate + variance + integralResult
    
    result = (endTime - startTime) * 1000.0

# complex number type
type Complex = object
    real, imag: float64

proc `+`(a, b: Complex): Complex =
    Complex(real: a.real + b.real, imag: a.imag + b.imag)

proc `-`(a, b: Complex): Complex =
    Complex(real: a.real - b.real, imag: a.imag - b.imag)

proc `*`(a, b: Complex): Complex =
    Complex(real: a.real * b.real - a.imag * b.imag,
            imag: a.real * b.imag + a.imag * b.real)

proc polar(magnitude, angle: float64): Complex =
    Complex(real: magnitude * cos(angle), imag: magnitude * sin(angle))

proc abs(c: Complex): float64 =
    sqrt(c.real * c.real + c.imag * c.imag)

proc fft(data: var seq[Complex]) =
    let n = data.len
    if n <= 1: return
    
    # use pre-allocated arrays to reduce allocations
    var 
        even = newSeqOfCap[Complex](n div 2 + 1)
        odd = newSeqOfCap[Complex](n div 2 + 1)
    
    # bit reversal pattern optimization
    for i in 0..<(n div 2):
        even.add(data[i * 2])
        odd.add(data[i * 2 + 1])
    
    fft(even)
    fft(odd)
    
    # butterfly computation
    for i in 0..<(n div 2):
        let t = polar(1.0, -2.0 * PI * i.float / n.float) * odd[i]
        data[i] = even[i] + t
        data[i + n div 2] = even[i] - t

proc ifft(data: var seq[Complex]) =
    let n = data.len
    for i in 0..<n:
        data[i].imag = -data[i].imag
    fft(data)
    for i in 0..<n:
        data[i].real /= n.float
        data[i].imag = -data[i].imag / n.float

proc signalProcessing(size: int): float =
    randomize(42)
    
    var 
        signal = newSeqOfCap[Complex](size)
        kernel = newSeqOfCap[Complex](size)
    
    for i in 0..<size:
        signal.add(Complex(real: rand(2.0) - 1.0, imag: rand(2.0) - 1.0))
        kernel.add(Complex(real: rand(2.0) - 1.0, imag: 0.0))
    
    let startTime = epochTime()
    
    # avoid unnecessary copies
    var 
        signalFft = signal
        kernelFft = kernel
        resultData = newSeqOfCap[Complex](size)
    
    # forward fft
    fft(signalFft)
    fft(kernelFft)
    
    # convolution in frequency domain
    for i in 0..<size:
        resultData.add(signalFft[i] * kernelFft[i])
    
    # inverse fft
    ifft(resultData)
    
    # round trip test
    var roundtrip = signal
    fft(roundtrip)
    ifft(roundtrip)
    
    var errorSum = 0.0
    for i in 0..<size:
        errorSum += abs(roundtrip[i] - signal[i])
    
    let endTime = epochTime()
    
    # prevent optimization
    var sum = 0.0
    for val in resultData:
        sum += abs(val)
    sum += errorSum
    discard sum
    
    result = (endTime - startTime) * 1000.0

proc heapify(arr: var seq[int], n, i: int) =
    var largest = i
    let 
        left = 2 * i + 1
        right = 2 * i + 2
    
    if left < n and arr[left] > arr[largest]:
        largest = left
    if right < n and arr[right] > arr[largest]:
        largest = right
    
    if largest != i:
        swap(arr[i], arr[largest])
        heapify(arr, n, largest)

proc heapSort(arr: var seq[int]) =
    let n = arr.len
    
    # build max heap
    for i in countdown(n div 2 - 1, 0):
        heapify(arr, n, i)
    
    # extract elements
    for i in countdown(n - 1, 1):
        swap(arr[0], arr[i])
        heapify(arr, i, 0)

proc binarySearch(arr: seq[int], target: int): int =
    var 
        left = 0
        right = arr.len - 1
    
    while left <= right:
        let mid = left + (right - left) div 2  # avoid overflow
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1
    
    return -1

proc dataStructures(size: int): float =
    randomize(42)
    
    var 
        data1 = newSeqOfCap[int](size)
        data2 = newSeqOfCap[int](size)
        data3 = newSeqOfCap[int](size)
    
    for i in 0..<size:
        data1.add(rand(size * 10) + 1)
        data2.add(i)
        data3.add(size - i)
    
    let startTime = epochTime()
    
    # multiple sorting algorithms
    data1.sort()
    heapSort(data2)
    data3.sort()
    
    # optimized merge operation
    var merged = newSeqOfCap[int](size * 2)
    var i = 0
    var j = 0 
    while i < size and j < size:
        if data1[i] <= data2[j]:
            merged.add(data1[i])
            inc i
        else:
            merged.add(data2[j])
            inc j
    
    # add remaining elements
    while i < size:
        merged.add(data1[i])
        inc i
    while j < size:
        merged.add(data2[j])
        inc j
    
    # binary search operations - optimized loop
    var foundCount = 0
    for i in 0..<2000:
        let target = rand(size * 10) + 1
        if binarySearch(data1, target) >= 0:
            inc foundCount
        if binarySearch(data2, target) >= 0:
            inc foundCount
    
    let endTime = epochTime()
    
    # prevent optimization
    discard foundCount + merged[size] + data3.len
    
    result = (endTime - startTime) * 1000.0

proc main() =
    var scaleFactor = 1
    
    if paramCount() > 0:
        try:
            scaleFactor = parseInt(paramStr(1))
            if scaleFactor < 1 or scaleFactor > 5:
                stderr.writeLine("Scale factor must be between 1 and 5")
                quit(1)
        except ValueError:
            stderr.writeLine("Invalid scale factor: " & paramStr(1))
            quit(1)
    
    var totalTime = 0.0
    
    totalTime += matrixOperations(40 * scaleFactor)
    totalTime += numberTheory(80000 * scaleFactor)
    totalTime += statisticalComputing(300000 * scaleFactor)
    totalTime += signalProcessing(256 * scaleFactor)
    totalTime += dataStructures(30000 * scaleFactor)
    
    echo fmt"{totalTime:.3f}"

when isMainModule:
    main()