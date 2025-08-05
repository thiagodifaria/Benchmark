package main

import (
	"fmt"
	"math"
	"math/cmplx"
	"math/rand"
	"os"
	"sort"
	"strconv"
	"time"
)

func matrixOperations(size int) float64 {
	a := make([][]float64, size)
	b := make([][]float64, size)
	c := make([][]float64, size)
	temp := make([][]float64, size)
	
	for i := range a {
		a[i] = make([]float64, size)
		b[i] = make([]float64, size)
		c[i] = make([]float64, size)
		temp[i] = make([]float64, size)
	}
	
	rand.Seed(42)
	for i := 0; i < size; i++ {
		for j := 0; j < size; j++ {
			a[i][j] = rand.Float64()*9 + 1
			b[i][j] = rand.Float64()*9 + 1
		}
	}
	
	start := time.Now()
	
	// blocked matrix multiplication
	block := 32
	for ii := 0; ii < size; ii += block {
		for jj := 0; jj < size; jj += block {
			for kk := 0; kk < size; kk += block {
				iMax := min(ii+block, size)
				jMax := min(jj+block, size)
				kMax := min(kk+block, size)
				for i := ii; i < iMax; i++ {
					for j := jj; j < jMax; j++ {
						for k := kk; k < kMax; k++ {
							c[i][j] += a[i][k] * b[k][j]
						}
					}
				}
			}
		}
	}
	
	// matrix transpose
	for i := 0; i < size; i++ {
		for j := 0; j < size; j++ {
			temp[j][i] = c[i][j]
		}
	}
	
	// matrix operations
	scalar := 1.5
	for i := 0; i < size; i++ {
		for j := 0; j < size; j++ {
			c[i][j] = temp[i][j] + a[i][j]*scalar
		}
	}
	
	duration := time.Since(start)
	
	sum := 0.0
	for i := 0; i < size; i++ {
		sum += c[i][i]
	}
	_ = sum
	
	return float64(duration.Nanoseconds()) / 1000000.0
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func isPrimeFast(n int64) bool {
	if n < 2 {
		return false
	}
	if n == 2 || n == 3 {
		return true
	}
	if n%2 == 0 || n%3 == 0 {
		return false
	}
	
	for i := int64(5); i*i <= n; i += 6 {
		if n%i == 0 || n%(i+2) == 0 {
			return false
		}
	}
	return true
}

func factorize(n int) []int {
	factors := []int{}
	for i := 2; i*i <= n; i++ {
		for n%i == 0 {
			factors = append(factors, i)
			n /= i
		}
	}
	if n > 1 {
		factors = append(factors, n)
	}
	return factors
}

func numberTheory(limit int) float64 {
	start := time.Now()
	
	isPrime := make([]bool, limit+1)
	for i := range isPrime {
		isPrime[i] = true
	}
	isPrime[0] = false
	isPrime[1] = false
	
	// segmented sieve
	for i := 2; i*i <= limit; i++ {
		if isPrime[i] {
			for j := i * i; j <= limit; j += i {
				isPrime[j] = false
			}
		}
	}
	
	// primality testing and factorization
	primeCount := 0
	compositeFactors := 0
	for i := limit - 1000; i <= limit; i++ {
		if isPrimeFast(int64(i)) {
			primeCount++
		} else {
			factors := factorize(i)
			compositeFactors += len(factors)
		}
	}
	
	// twin prime counting
	twinPrimes := 0
	for i := 3; i <= limit-2; i++ {
		if isPrime[i] && isPrime[i+2] {
			twinPrimes++
		}
	}
	
	duration := time.Since(start)
	result := primeCount + compositeFactors + twinPrimes
	_ = result
	
	return float64(duration.Nanoseconds()) / 1000000.0
}

func statisticalComputing(samples int) float64 {
	start := time.Now()
	
	rand.Seed(42)
	insideCircle := 0
	values := make([]float64, 0, samples)
	
	// monte carlo and normal distribution sampling
	for i := 0; i < samples; i++ {
		x := rand.Float64()
		y := rand.Float64()
		if x*x+y*y <= 1.0 {
			insideCircle++
		}
		
		// box-muller for normal distribution
		if i%2 == 0 {
			u1 := rand.Float64()
			u2 := rand.Float64()
			z0 := math.Sqrt(-2*math.Log(u1)) * math.Cos(2*math.Pi*u2)
			values = append(values, z0)
		}
	}
	
	piEstimate := 4.0 * float64(insideCircle) / float64(samples)
	
	// statistical calculations
	mean := 0.0
	for _, val := range values {
		mean += val
	}
	mean /= float64(len(values))
	
	variance := 0.0
	for _, val := range values {
		diff := val - mean
		variance += diff * diff
	}
	variance /= float64(len(values))
	
	// numerical integration
	integrationSamples := samples / 4
	integralSum := 0.0
	for i := 0; i < integrationSamples; i++ {
		x := rand.Float64() * math.Pi / 2
		integralSum += math.Sin(x)
	}
	integralResult := (math.Pi / 2) * integralSum / float64(integrationSamples)
	
	duration := time.Since(start)
	result := piEstimate + variance + integralResult
	_ = result
	
	return float64(duration.Nanoseconds()) / 1000000.0
}

func fft(data []complex128) {
	n := len(data)
	if n <= 1 {
		return
	}
	
	even := make([]complex128, n/2)
	odd := make([]complex128, n/2)
	
	for i := 0; i < n/2; i++ {
		even[i] = data[i*2]
		odd[i] = data[i*2+1]
	}
	
	fft(even)
	fft(odd)
	
	for i := 0; i < n/2; i++ {
		t := cmplx.Exp(complex(0, -2*math.Pi*float64(i)/float64(n))) * odd[i]
		data[i] = even[i] + t
		data[i+n/2] = even[i] - t
	}
}

func ifft(data []complex128) {
	n := len(data)
	for i := range data {
		data[i] = cmplx.Conj(data[i])
	}
	fft(data)
	for i := range data {
		data[i] = cmplx.Conj(data[i]) / complex(float64(n), 0)
	}
}

func signalProcessing(size int) float64 {
	signal := make([]complex128, size)
	kernel := make([]complex128, size)
	result := make([]complex128, size)
	
	rand.Seed(42)
	for i := 0; i < size; i++ {
		real := rand.Float64()*2 - 1
		imag := rand.Float64()*2 - 1
		signal[i] = complex(real, imag)
		kernel[i] = complex(rand.Float64()*2-1, 0)
	}
	
	start := time.Now()
	
	// prepare fft data
	signalFFT := make([]complex128, size)
	kernelFFT := make([]complex128, size)
	copy(signalFFT, signal)
	copy(kernelFFT, kernel)
	
	// forward fft
	fft(signalFFT)
	fft(kernelFFT)
	
	// convolution in frequency domain
	for i := 0; i < size; i++ {
		result[i] = signalFFT[i] * kernelFFT[i]
	}
	
	// inverse fft
	ifft(result)
	
	// round trip test
	roundtrip := make([]complex128, size)
	copy(roundtrip, signal)
	fft(roundtrip)
	ifft(roundtrip)
	
	errorSum := 0.0
	for i := 0; i < size; i++ {
		errorSum += cmplx.Abs(roundtrip[i] - signal[i])
	}
	
	duration := time.Since(start)
	
	sum := 0.0
	for _, val := range result {
		sum += cmplx.Abs(val)
	}
	sum += errorSum
	_ = sum
	
	return float64(duration.Nanoseconds()) / 1000000.0
}

func heapify(arr []int, n, i int) {
	largest := i
	left := 2*i + 1
	right := 2*i + 2
	
	if left < n && arr[left] > arr[largest] {
		largest = left
	}
	if right < n && arr[right] > arr[largest] {
		largest = right
	}
	
	if largest != i {
		arr[i], arr[largest] = arr[largest], arr[i]
		heapify(arr, n, largest)
	}
}

func heapSort(arr []int) {
	n := len(arr)
	
	for i := n/2 - 1; i >= 0; i-- {
		heapify(arr, n, i)
	}
	
	for i := n - 1; i > 0; i-- {
		arr[0], arr[i] = arr[i], arr[0]
		heapify(arr, i, 0)
	}
}

func dataStructures(size int) float64 {
	data1 := make([]int, size)
	data2 := make([]int, size)
	data3 := make([]int, size)
	
	rand.Seed(42)
	for i := 0; i < size; i++ {
		data1[i] = rand.Intn(size*10) + 1
		data2[i] = i
		data3[i] = size - i
	}
	
	start := time.Now()
	
	// multiple sorting algorithms
	sort.Ints(data1)
	heapSort(data2)
	sort.Slice(data3, func(i, j int) bool { return data3[i] < data3[j] })
	
	// merge operation
	merged := make([]int, 0, size*2)
	i, j := 0, 0
	for i < len(data1) && j < len(data2) {
		if data1[i] <= data2[j] {
			merged = append(merged, data1[i])
			i++
		} else {
			merged = append(merged, data2[j])
			j++
		}
	}
	for i < len(data1) {
		merged = append(merged, data1[i])
		i++
	}
	for j < len(data2) {
		merged = append(merged, data2[j])
		j++
	}
	
	// binary search operations
	foundCount := 0
	for i := 0; i < 2000; i++ {
		target := rand.Intn(size*10) + 1
		idx1 := sort.SearchInts(data1, target)
		if idx1 < len(data1) && data1[idx1] == target {
			foundCount++
		}
		idx2 := sort.SearchInts(data2, target)
		if idx2 < len(data2) && data2[idx2] == target {
			foundCount++
		}
	}
	
	duration := time.Since(start)
	result := foundCount + len(merged) + len(data3)
	_ = result
	
	return float64(duration.Nanoseconds()) / 1000000.0
}

func main() {
	scaleFactor := 1
	
	if len(os.Args) > 1 {
		var err error
		scaleFactor, err = strconv.Atoi(os.Args[1])
		if err != nil {
			fmt.Println("Invalid scale factor:", os.Args[1])
			os.Exit(1)
		}
		if scaleFactor < 1 || scaleFactor > 5 {
			fmt.Println("Scale factor must be between 1 and 5")
			os.Exit(1)
		}
	}
	
	totalTime := 0.0
	
	totalTime += matrixOperations(40 * scaleFactor)
	totalTime += numberTheory(80000 * scaleFactor)
	totalTime += statisticalComputing(300000 * scaleFactor)
	totalTime += signalProcessing(256 * scaleFactor)
	totalTime += dataStructures(30000 * scaleFactor)
	
	fmt.Printf("%.3f\n", totalTime)
}