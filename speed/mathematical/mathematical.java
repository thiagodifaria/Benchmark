import java.util.*;

public class mathematical {
    
    static double matrixOperations(int size) {
        double[][] a = new double[size][size];
        double[][] b = new double[size][size];
        double[][] c = new double[size][size];
        double[][] temp = new double[size][size];
        
        Random rand = new Random(42);
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                a[i][j] = rand.nextDouble() * 9 + 1;
                b[i][j] = rand.nextDouble() * 9 + 1;
            }
        }
        
        long start = System.nanoTime();
        
        // blocked matrix multiplication
        int block = 32;
        for (int ii = 0; ii < size; ii += block) {
            for (int jj = 0; jj < size; jj += block) {
                for (int kk = 0; kk < size; kk += block) {
                    int iMax = Math.min(ii + block, size);
                    int jMax = Math.min(jj + block, size);
                    int kMax = Math.min(kk + block, size);
                    for (int i = ii; i < iMax; i++) {
                        for (int j = jj; j < jMax; j++) {
                            for (int k = kk; k < kMax; k++) {
                                c[i][j] += a[i][k] * b[k][j];
                            }
                        }
                    }
                }
            }
        }
        
        // matrix transpose
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                temp[j][i] = c[i][j];
            }
        }
        
        // matrix operations
        double scalar = 1.5;
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                c[i][j] = temp[i][j] + a[i][j] * scalar;
            }
        }
        
        long end = System.nanoTime();
        
        double sum = 0;
        for (int i = 0; i < size; i++) {
            sum += c[i][i];
        }
        
        return (end - start) / 1000000.0;
    }
    
    static boolean isPrimeFast(long n) {
        if (n < 2) return false;
        if (n == 2 || n == 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;
        
        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }
    
    static List<Integer> factorize(int n) {
        List<Integer> factors = new ArrayList<>();
        for (int i = 2; i * i <= n; i++) {
            while (n % i == 0) {
                factors.add(i);
                n /= i;
            }
        }
        if (n > 1) factors.add(n);
        return factors;
    }
    
    static double numberTheory(int limit) {
        long start = System.nanoTime();
        
        boolean[] isPrime = new boolean[limit + 1];
        Arrays.fill(isPrime, true);
        isPrime[0] = isPrime[1] = false;
        
        // segmented sieve
        for (int i = 2; i * i <= limit; i++) {
            if (isPrime[i]) {
                for (int j = i * i; j <= limit; j += i) {
                    isPrime[j] = false;
                }
            }
        }
        
        // primality testing and factorization
        int primeCount = 0;
        int compositeFactors = 0;
        for (int i = limit - 1000; i <= limit; i++) {
            if (isPrimeFast(i)) {
                primeCount++;
            } else {
                List<Integer> factors = factorize(i);
                compositeFactors += factors.size();
            }
        }
        
        // twin prime counting
        int twinPrimes = 0;
        for (int i = 3; i <= limit - 2; i++) {
            if (isPrime[i] && isPrime[i + 2]) {
                twinPrimes++;
            }
        }
        
        long end = System.nanoTime();
        int result = primeCount + compositeFactors + twinPrimes;
        
        return (end - start) / 1000000.0;
    }
    
    static double statisticalComputing(int samples) {
        long start = System.nanoTime();
        
        Random rand = new Random(42);
        int insideCircle = 0;
        List<Double> values = new ArrayList<>();
        
        // monte carlo and normal distribution
        for (int i = 0; i < samples; i++) {
            double x = rand.nextDouble();
            double y = rand.nextDouble();
            if (x * x + y * y <= 1.0) {
                insideCircle++;
            }
            
            // box-muller for normal distribution
            if (i % 2 == 0) {
                double u1 = rand.nextDouble();
                double u2 = rand.nextDouble();
                double z0 = Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
                values.add(z0);
            }
        }
        
        double piEstimate = 4.0 * insideCircle / samples;
        
        // statistical calculations
        double mean = values.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
        double variance = values.stream()
            .mapToDouble(val -> Math.pow(val - mean, 2))
            .average().orElse(0.0);
        
        // numerical integration
        int integrationSamples = samples / 4;
        double integralSum = 0.0;
        for (int i = 0; i < integrationSamples; i++) {
            double x = rand.nextDouble() * Math.PI / 2;
            integralSum += Math.sin(x);
        }
        double integralResult = (Math.PI / 2) * integralSum / integrationSamples;
        
        long end = System.nanoTime();
        double result = piEstimate + variance + integralResult;
        
        return (end - start) / 1000000.0;
    }
    
    static class Complex {
        double real, imag;
        
        Complex(double real, double imag) {
            this.real = real;
            this.imag = imag;
        }
        
        Complex add(Complex other) {
            return new Complex(real + other.real, imag + other.imag);
        }
        
        Complex subtract(Complex other) {
            return new Complex(real - other.real, imag - other.imag);
        }
        
        Complex multiply(Complex other) {
            return new Complex(real * other.real - imag * other.imag,
                             real * other.imag + imag * other.real);
        }
        
        static Complex polar(double magnitude, double angle) {
            return new Complex(magnitude * Math.cos(angle), magnitude * Math.sin(angle));
        }
        
        Complex conjugate() {
            return new Complex(real, -imag);
        }
        
        Complex divide(double divisor) {
            return new Complex(real / divisor, imag / divisor);
        }
        
        double abs() {
            return Math.sqrt(real * real + imag * imag);
        }
    }
    
    static void fft(Complex[] data) {
        int n = data.length;
        if (n <= 1) return;
        
        Complex[] even = new Complex[n/2];
        Complex[] odd = new Complex[n/2];
        
        for (int i = 0; i < n/2; i++) {
            even[i] = data[i*2];
            odd[i] = data[i*2+1];
        }
        
        fft(even);
        fft(odd);
        
        for (int i = 0; i < n/2; i++) {
            Complex t = Complex.polar(1.0, -2 * Math.PI * i / n).multiply(odd[i]);
            data[i] = even[i].add(t);
            data[i + n/2] = even[i].subtract(t);
        }
    }
    
    static void ifft(Complex[] data) {
        int n = data.length;
        for (int i = 0; i < n; i++) {
            data[i] = data[i].conjugate();
        }
        fft(data);
        for (int i = 0; i < n; i++) {
            data[i] = data[i].conjugate().divide(n);
        }
    }
    
    static double signalProcessing(int size) {
        Complex[] signal = new Complex[size];
        Complex[] kernel = new Complex[size];
        Complex[] result = new Complex[size];
        
        Random rand = new Random(42);
        for (int i = 0; i < size; i++) {
            double real = rand.nextDouble() * 2 - 1;
            double imag = rand.nextDouble() * 2 - 1;
            signal[i] = new Complex(real, imag);
            kernel[i] = new Complex(rand.nextDouble() * 2 - 1, 0);
        }
        
        long start = System.nanoTime();
        
        // prepare fft arrays
        Complex[] signalFFT = signal.clone();
        Complex[] kernelFFT = kernel.clone();
        
        // forward fft
        fft(signalFFT);
        fft(kernelFFT);
        
        // convolution in frequency domain
        for (int i = 0; i < size; i++) {
            result[i] = signalFFT[i].multiply(kernelFFT[i]);
        }
        
        // inverse fft
        ifft(result);
        
        // round trip test
        Complex[] roundtrip = signal.clone();
        fft(roundtrip);
        ifft(roundtrip);
        
        double errorSum = 0.0;
        for (int i = 0; i < size; i++) {
            errorSum += roundtrip[i].subtract(signal[i]).abs();
        }
        
        long end = System.nanoTime();
        
        double sum = 0;
        for (Complex val : result) {
            sum += val.abs();
        }
        sum += errorSum;
        
        return (end - start) / 1000000.0;
    }
    
    static void heapify(int[] arr, int n, int i) {
        int largest = i;
        int left = 2 * i + 1;
        int right = 2 * i + 2;
        
        if (left < n && arr[left] > arr[largest])
            largest = left;
        if (right < n && arr[right] > arr[largest])
            largest = right;
        
        if (largest != i) {
            int swap = arr[i];
            arr[i] = arr[largest];
            arr[largest] = swap;
            heapify(arr, n, largest);
        }
    }
    
    static void heapSort(int[] arr) {
        int n = arr.length;
        
        for (int i = n / 2 - 1; i >= 0; i--)
            heapify(arr, n, i);
        
        for (int i = n - 1; i > 0; i--) {
            int temp = arr[0];
            arr[0] = arr[i];
            arr[i] = temp;
            heapify(arr, i, 0);
        }
    }
    
    static double dataStructures(int size) {
        int[] data1 = new int[size];
        int[] data2 = new int[size];
        Integer[] data3 = new Integer[size];
        
        Random rand = new Random(42);
        for (int i = 0; i < size; i++) {
            data1[i] = rand.nextInt(size * 10) + 1;
            data2[i] = i;
            data3[i] = size - i;
        }
        
        long start = System.nanoTime();
        
        // multiple sorting algorithms
        Arrays.sort(data1);
        heapSort(data2);
        Arrays.sort(data3);
        
        // merge operation
        List<Integer> merged = new ArrayList<>();
        int i = 0, j = 0;
        while (i < data1.length && j < data2.length) {
            if (data1[i] <= data2[j]) {
                merged.add(data1[i++]);
            } else {
                merged.add(data2[j++]);
            }
        }
        while (i < data1.length) merged.add(data1[i++]);
        while (j < data2.length) merged.add(data2[j++]);
        
        // binary search operations
        int foundCount = 0;
        for (int k = 0; k < 2000; k++) {
            int target = rand.nextInt(size * 10) + 1;
            if (Arrays.binarySearch(data1, target) >= 0) foundCount++;
            if (Arrays.binarySearch(data2, target) >= 0) foundCount++;
        }
        
        // priority queue operations
        PriorityQueue<Integer> heap = new PriorityQueue<>(Collections.reverseOrder());
        for (int val : data3) {
            heap.offer(val);
        }
        for (int k = 0; k < 100; k++) {
            heap.poll();
            heap.offer(rand.nextInt(size * 10) + 1);
        }
        
        long end = System.nanoTime();
        int result = foundCount + merged.size() + heap.size();
        
        return (end - start) / 1000000.0;
    }
    
    public static void main(String[] args) {
        int scaleFactor = 1;
        
        if (args.length > 0) {
            try {
                scaleFactor = Integer.parseInt(args[0]);
                if (scaleFactor < 1 || scaleFactor > 5) {
                    System.err.println("Scale factor must be between 1 and 5");
                    System.exit(1);
                }
            } catch (NumberFormatException e) {
                System.err.println("Invalid scale factor: " + args[0]);
                System.exit(1);
            }
        }
        
        double totalTime = 0;
        
        totalTime += matrixOperations(40 * scaleFactor);
        totalTime += numberTheory(80000 * scaleFactor);
        totalTime += statisticalComputing(300000 * scaleFactor);
        totalTime += signalProcessing(256 * scaleFactor);
        totalTime += dataStructures(30000 * scaleFactor);
        
        System.out.printf("%.3f%n", totalTime);
    }
}