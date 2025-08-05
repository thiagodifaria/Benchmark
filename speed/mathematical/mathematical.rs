use std::env;
use std::time::Instant;
use std::f64::consts::PI;
use std::collections::BinaryHeap;

fn matrix_operations(size: usize) -> f64 {
    let mut a = vec![vec![0.0; size]; size];
    let mut b = vec![vec![0.0; size]; size];
    let mut c = vec![vec![0.0; size]; size];
    let mut temp = vec![vec![0.0; size]; size];
    
    let mut rng = 42u64;
    for i in 0..size {
        for j in 0..size {
            rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
            a[i][j] = ((rng >> 16) & 0x7fff) as f64 / 32767.0 * 9.0 + 1.0;
            rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
            b[i][j] = ((rng >> 16) & 0x7fff) as f64 / 32767.0 * 9.0 + 1.0;
        }
    }
    
    let start = Instant::now();
    
    // blocked matrix multiplication
    let block = 32;
    for ii in (0..size).step_by(block) {
        for jj in (0..size).step_by(block) {
            for kk in (0..size).step_by(block) {
                let i_max = (ii + block).min(size);
                let j_max = (jj + block).min(size);
                let k_max = (kk + block).min(size);
                for i in ii..i_max {
                    for j in jj..j_max {
                        for k in kk..k_max {
                            c[i][j] += a[i][k] * b[k][j];
                        }
                    }
                }
            }
        }
    }
    
    // matrix transpose
    for i in 0..size {
        for j in 0..size {
            temp[j][i] = c[i][j];
        }
    }
    
    // matrix operations
    let scalar = 1.5;
    for i in 0..size {
        for j in 0..size {
            c[i][j] = temp[i][j] + a[i][j] * scalar;
        }
    }
    
    let duration = start.elapsed();
    
    let sum: f64 = (0..size).map(|i| c[i][i]).sum();
    std::hint::black_box(sum);
    
    duration.as_secs_f64() * 1000.0
}

fn is_prime_fast(n: u64) -> bool {
    if n < 2 {
        return false;
    }
    if n == 2 || n == 3 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }
    
    let mut i = 5;
    while i * i <= n {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }
    true
}

fn factorize(mut n: usize) -> Vec<usize> {
    let mut factors = Vec::new();
    let mut i = 2;
    while i * i <= n {
        while n % i == 0 {
            factors.push(i);
            n /= i;
        }
        i += 1;
    }
    if n > 1 {
        factors.push(n);
    }
    factors
}

fn number_theory(limit: usize) -> f64 {
    let start = Instant::now();
    
    let mut is_prime = vec![true; limit + 1];
    is_prime[0] = false;
    if limit > 0 {
        is_prime[1] = false;
    }
    
    // segmented sieve
    let mut i = 2;
    while i * i <= limit {
        if is_prime[i] {
            let mut j = i * i;
            while j <= limit {
                is_prime[j] = false;
                j += i;
            }
        }
        i += 1;
    }
    
    // primality testing and factorization
    let mut prime_count = 0;
    let mut composite_factors = 0;
    for i in (limit.saturating_sub(1000))..=limit {
        if is_prime_fast(i as u64) {
            prime_count += 1;
        } else {
            let factors = factorize(i);
            composite_factors += factors.len();
        }
    }
    
    // twin prime counting
    let mut twin_primes = 0;
    for i in 3..=(limit.saturating_sub(2)) {
        if i + 2 <= limit && is_prime[i] && is_prime[i + 2] {
            twin_primes += 1;
        }
    }
    
    let duration = start.elapsed();
    let result = prime_count + composite_factors + twin_primes;
    std::hint::black_box(result);
    
    duration.as_secs_f64() * 1000.0
}

fn statistical_computing(samples: usize) -> f64 {
    let start = Instant::now();
    
    let mut rng = 42u64;
    let mut inside_circle = 0;
    let mut values = Vec::new();
    
    // monte carlo and normal distribution
    for i in 0..samples {
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let x = ((rng >> 16) & 0x7fff) as f64 / 32767.0;
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let y = ((rng >> 16) & 0x7fff) as f64 / 32767.0;
        
        if x * x + y * y <= 1.0 {
            inside_circle += 1;
        }
        
        // box-muller for normal distribution
        if i % 2 == 0 {
            rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
            let u1 = ((rng >> 16) & 0x7fff) as f64 / 32767.0;
            rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
            let u2 = ((rng >> 16) & 0x7fff) as f64 / 32767.0;
            let z0 = (-2.0 * u1.ln()).sqrt() * (2.0 * PI * u2).cos();
            values.push(z0);
        }
    }
    
    let pi_estimate = 4.0 * inside_circle as f64 / samples as f64;
    
    // statistical calculations
    let mean = values.iter().sum::<f64>() / values.len() as f64;
    let variance = values.iter()
        .map(|&val| (val - mean).powi(2))
        .sum::<f64>() / values.len() as f64;
    
    // numerical integration
    let integration_samples = samples / 4;
    let mut integral_sum = 0.0;
    for _ in 0..integration_samples {
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let x = ((rng >> 16) & 0x7fff) as f64 / 32767.0 * PI / 2.0;
        integral_sum += x.sin();
    }
    let integral_result = (PI / 2.0) * integral_sum / integration_samples as f64;
    
    let duration = start.elapsed();
    let result = pi_estimate + variance + integral_result;
    std::hint::black_box(result);
    
    duration.as_secs_f64() * 1000.0
}

#[derive(Clone, Copy)]
struct Complex {
    real: f64,
    imag: f64,
}

impl Complex {
    fn new(real: f64, imag: f64) -> Self {
        Complex { real, imag }
    }
    
    fn add(self, other: Complex) -> Complex {
        Complex::new(self.real + other.real, self.imag + other.imag)
    }
    
    fn subtract(self, other: Complex) -> Complex {
        Complex::new(self.real - other.real, self.imag - other.imag)
    }
    
    fn multiply(self, other: Complex) -> Complex {
        Complex::new(
            self.real * other.real - self.imag * other.imag,
            self.real * other.imag + self.imag * other.real,
        )
    }
    
    fn polar(magnitude: f64, angle: f64) -> Complex {
        Complex::new(magnitude * angle.cos(), magnitude * angle.sin())
    }
    
    fn conjugate(self) -> Complex {
        Complex::new(self.real, -self.imag)
    }
    
    fn divide_scalar(self, divisor: f64) -> Complex {
        Complex::new(self.real / divisor, self.imag / divisor)
    }
    
    fn abs(self) -> f64 {
        (self.real * self.real + self.imag * self.imag).sqrt()
    }
}

fn fft(data: &mut [Complex]) {
    let n = data.len();
    if n <= 1 {
        return;
    }
    
    let mut even: Vec<Complex> = (0..n).step_by(2).map(|i| data[i]).collect();
    let mut odd: Vec<Complex> = (1..n).step_by(2).map(|i| data[i]).collect();
    
    fft(&mut even);
    fft(&mut odd);
    
    for i in 0..n/2 {
        let t = Complex::polar(1.0, -2.0 * PI * i as f64 / n as f64).multiply(odd[i]);
        data[i] = even[i].add(t);
        data[i + n/2] = even[i].subtract(t);
    }
}

fn ifft(data: &mut [Complex]) {
    let n = data.len();
    for val in data.iter_mut() {
        *val = val.conjugate();
    }
    fft(data);
    for val in data.iter_mut() {
        *val = val.conjugate().divide_scalar(n as f64);
    }
}

fn signal_processing(size: usize) -> f64 {
    let mut signal = Vec::with_capacity(size);
    let mut kernel = Vec::with_capacity(size);
    
    let mut rng = 42u64;
    for _ in 0..size {
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let real = ((rng >> 16) & 0x7fff) as f64 / 16383.5 - 1.0;
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let imag = ((rng >> 16) & 0x7fff) as f64 / 16383.5 - 1.0;
        signal.push(Complex::new(real, imag));
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let kernel_real = ((rng >> 16) & 0x7fff) as f64 / 16383.5 - 1.0;
        kernel.push(Complex::new(kernel_real, 0.0));
    }
    
    let start = Instant::now();
    
    // prepare fft arrays
    let mut signal_fft = signal.clone();
    let mut kernel_fft = kernel.clone();
    
    // forward fft
    fft(&mut signal_fft);
    fft(&mut kernel_fft);
    
    // convolution in frequency domain
    let mut result: Vec<Complex> = signal_fft.iter()
        .zip(kernel_fft.iter())
        .map(|(&s, &k)| s.multiply(k))
        .collect();
    
    // inverse fft
    ifft(&mut result);
    
    // round trip test
    let mut roundtrip = signal.clone();
    fft(&mut roundtrip);
    ifft(&mut roundtrip);
    
    let error_sum: f64 = roundtrip.iter()
        .zip(signal.iter())
        .map(|(&rt, &orig)| rt.subtract(orig).abs())
        .sum();
    
    let duration = start.elapsed();
    
    let sum: f64 = result.iter().map(|val| val.abs()).sum::<f64>() + error_sum;
    std::hint::black_box(sum);
    
    duration.as_secs_f64() * 1000.0
}

fn heapify(arr: &mut [i32], n: usize, i: usize) {
    let mut largest = i;
    let left = 2 * i + 1;
    let right = 2 * i + 2;
    
    if left < n && arr[left] > arr[largest] {
        largest = left;
    }
    if right < n && arr[right] > arr[largest] {
        largest = right;
    }
    
    if largest != i {
        arr.swap(i, largest);
        heapify(arr, n, largest);
    }
}

fn heap_sort(arr: &mut [i32]) {
    let n = arr.len();
    
    for i in (0..n/2).rev() {
        heapify(arr, n, i);
    }
    
    for i in (1..n).rev() {
        arr.swap(0, i);
        heapify(arr, i, 0);
    }
}

fn data_structures(size: usize) -> f64 {
    let mut data1 = Vec::with_capacity(size);
    let mut data2 = Vec::with_capacity(size);
    let mut data3 = Vec::with_capacity(size);
    
    let mut rng = 42u64;
    for i in 0..size {
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        data1.push(((rng >> 16) & 0x7fff) as i32 % (size as i32 * 10) + 1);
        data2.push(i as i32);
        data3.push((size - i) as i32);
    }
    
    let start = Instant::now();
    
    // multiple sorting algorithms
    data1.sort_unstable();
    heap_sort(&mut data2);
    data3.sort();
    
    // merge operation
    let mut merged = Vec::with_capacity(size * 2);
    let mut i = 0;
    let mut j = 0;
    while i < data1.len() && j < data2.len() {
        if data1[i] <= data2[j] {
            merged.push(data1[i]);
            i += 1;
        } else {
            merged.push(data2[j]);
            j += 1;
        }
    }
    merged.extend_from_slice(&data1[i..]);
    merged.extend_from_slice(&data2[j..]);
    
    // binary search operations
    let mut found_count = 0;
    for _ in 0..2000 {
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let target = ((rng >> 16) & 0x7fff) as i32 % (size as i32 * 10) + 1;
        if data1.binary_search(&target).is_ok() {
            found_count += 1;
        }
        if data2.binary_search(&target).is_ok() {
            found_count += 1;
        }
    }
    
    // heap operations
    let mut heap: BinaryHeap<i32> = data3.into_iter().collect();
    for _ in 0..100 {
        heap.pop();
        rng = rng.wrapping_mul(1103515245).wrapping_add(12345);
        let val = ((rng >> 16) & 0x7fff) as i32 % (size as i32 * 10) + 1;
        heap.push(val);
    }
    
    let duration = start.elapsed();
    let result = found_count + merged.len() + heap.len();
    std::hint::black_box(result);
    
    duration.as_secs_f64() * 1000.0
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut scale_factor = 1;
    
    if args.len() > 1 {
        match args[1].parse::<i32>() {
            Ok(factor) => {
                if factor < 1 || factor > 5 {
                    eprintln!("Scale factor must be between 1 and 5");
                    std::process::exit(1);
                }
                scale_factor = factor as usize;
            }
            Err(_) => {
                eprintln!("Invalid scale factor: {}", args[1]);
                std::process::exit(1);
            }
        }
    }
    
    let mut total_time = 0.0;
    
    total_time += matrix_operations(40 * scale_factor);
    total_time += number_theory(80000 * scale_factor);
    total_time += statistical_computing(300000 * scale_factor);
    total_time += signal_processing(256 * scale_factor);
    total_time += data_structures(30000 * scale_factor);
    
    println!("{:.3}", total_time);
}