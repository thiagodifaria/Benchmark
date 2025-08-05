import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

public class memory {
    
    // simple arena allocator class
    static class Arena {
        private byte[] buffer;
        private int used;
        
        public Arena(int size) {
            this.buffer = new byte[size];
            this.used = 0;
        }
        
        public byte[] allocate(int size) {
            // align to 8 bytes
            size = (size + 7) & ~7;
            
            if (used + size > buffer.length) {
                return null;
            }
            
            byte[] result = new byte[size];
            System.arraycopy(buffer, used, result, 0, size);
            used += size;
            return result;
        }
        
        public void reset() {
            used = 0;
        }
        
        public int capacity() { return buffer.length; }
        public int usage() { return used; }
    }
    
    // allocation patterns test - sequential, random, producer-consumer
    static double allocationPatternsTest(int iterations) {
        long start = System.nanoTime();
        
        // sequential allocation pattern
        List<byte[]> ptrs = new ArrayList<>(iterations);
        for (int i = 0; i < iterations; i++) {
            int size = 64 + (i % 256);
            ptrs.add(new byte[size]);
        }
        ptrs.clear();
        System.gc();
        
        // random allocation pattern
        Random rng = new Random(42);
        List<byte[]> rawPtrs = new ArrayList<>(iterations);
        
        for (int i = 0; i < iterations; i++) {
            int size = 32 + rng.nextInt(512);
            rawPtrs.add(new byte[size]);
        }
        
        // random deallocation (shuffle and clear)
        Collections.shuffle(rawPtrs, rng);
        rawPtrs.clear();
        System.gc();
        
        long end = System.nanoTime();
        return (end - start) / 1000000.0;
    }
    
    // worker class for gc stress test
    static class GcStressWorker implements Runnable {
        private final int threadId;
        private final int iterations;
        private final AtomicInteger counter;
        
        public GcStressWorker(int threadId, int iterations, AtomicInteger counter) {
            this.threadId = threadId;
            this.iterations = iterations;
            this.counter = counter;
        }
        
        @Override
        public void run() {
            Random rng = new Random(42 + threadId);
            
            for (int i = 0; i < iterations; i++) {
                int size = 16 + rng.nextInt(1024);
                byte[] data = new byte[size];
                
                // simulate work
                Arrays.fill(data, (byte)(i & 0xFF));
                
                byte sum = 0;
                for (int j = 0; j < size; j += 8) {
                    sum += data[j];
                }
                
                counter.incrementAndGet();
            }
        }
    }
    
    // gc stress testing with multiple threads
    static double gcStressTest(int numThreads, int iterationsPerThread) {
        long start = System.nanoTime();
        
        AtomicInteger counter = new AtomicInteger(0);
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        List<Future<?>> futures = new ArrayList<>();
        
        for (int i = 0; i < numThreads; i++) {
            futures.add(executor.submit(new GcStressWorker(i, iterationsPerThread, counter)));
        }
        
        try {
            for (Future<?> future : futures) {
                future.get();
            }
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            executor.shutdown();
        }
        
        int result = counter.get();
        
        long end = System.nanoTime();
        return (end - start) / 1000000.0;
    }
    
    // cache locality and fragmentation test
    static double cacheLocalityTest(int iterations) {
        long start = System.nanoTime();
        
        // allocate small and large objects interleaved
        List<byte[]> smallPtrs = new ArrayList<>(iterations);
        List<byte[]> largePtrs = new ArrayList<>(iterations);
        
        Random rng = new Random(42);
        
        // interleaved allocation pattern
        for (int i = 0; i < iterations; i++) {
            int smallSize = 16 + rng.nextInt(64);
            int largeSize = 1024 + rng.nextInt(4096);
            
            byte[] smallArray = new byte[smallSize];
            byte[] largeArray = new byte[largeSize];
            
            // access pattern to test spatial locality
            Arrays.fill(smallArray, (byte)(i & 0xFF));
            Arrays.fill(largeArray, 0, Math.min(1024, largeArray.length), (byte)((i + 1) & 0xFF));
            
            smallPtrs.add(smallArray);
            largePtrs.add(largeArray);
        }
        
        // random access pattern to stress cache
        for (int i = 0; i < iterations / 2; i++) {
            int idx1 = rng.nextInt(iterations);
            int idx2 = rng.nextInt(iterations);
            
            if (idx1 < smallPtrs.size()) {
                byte[] smallArray = smallPtrs.get(idx1);
                byte sum = 0;
                for (int j = 0; j < Math.min(16, smallArray.length); j++) {
                    sum += smallArray[j];
                }
            }
            
            if (idx2 < largePtrs.size()) {
                byte[] largeArray = largePtrs.get(idx2);
                byte sum = 0;
                for (int j = 0; j < Math.min(1024, largeArray.length); j += 64) {
                    sum += largeArray[j];
                }
            }
        }
        
        long end = System.nanoTime();
        return (end - start) / 1000000.0;
    }
    
    // memory pool performance test
    static double memoryPoolTest(int iterations) {
        long start = System.nanoTime();
        
        // test standard allocation
        List<byte[]> stdPtrs = new ArrayList<>(iterations);
        for (int i = 0; i < iterations; i++) {
            byte[] data = new byte[128];
            Arrays.fill(data, (byte)(i & 0xFF));
            stdPtrs.add(data);
        }
        stdPtrs.clear();
        System.gc();
        
        // test arena allocation
        Arena arena = new Arena(iterations * 128 + 1024);
        List<byte[]> arenaPtrs = new ArrayList<>(iterations);
        
        for (int i = 0; i < iterations; i++) {
            byte[] ptr = arena.allocate(128);
            if (ptr != null) {
                Arrays.fill(ptr, (byte)(i & 0xFF));
                arenaPtrs.add(ptr);
            }
        }
        
        // batch deallocation
        arena.reset();
        
        // test batch allocation
        for (int batch = 0; batch < 10; batch++) {
            for (int i = 0; i < iterations / 10; i++) {
                byte[] ptr = arena.allocate(128);
                if (ptr != null) {
                    Arrays.fill(ptr, (byte)(i & 0xFF));
                }
            }
            arena.reset();
        }
        
        long end = System.nanoTime();
        return (end - start) / 1000000.0;
    }
    
    // memory intensive workloads test
    static double memoryIntensiveTest(int largeSizeMb) {
        long start = System.nanoTime();
        
        int size = largeSizeMb * 1024 * 1024;
        
        // large object allocation
        byte[] largeArray1 = new byte[size];
        byte[] largeArray2 = new byte[size];
        
        // memory bandwidth test - sequential write
        for (int i = 0; i < size; i += 4096) {
            largeArray1[i] = (byte)(i & 0xFF);
        }
        
        // memory copy operations
        System.arraycopy(largeArray1, 0, largeArray2, 0, size);
        
        // memory bandwidth test - sequential read
        long sum = 0;
        for (int i = 0; i < size; i += 4096) {
            sum += largeArray2[i];
        }
        
        // memory access pattern test
        Random rng = new Random(42);
        for (int i = 0; i < 10000; i++) {
            int offset = rng.nextInt(size - 64);
            byte val = largeArray1[offset];
            largeArray2[offset] = (byte)(val + 1);
        }
        
        long end = System.nanoTime();
        return (end - start) / 1000000.0;
    }
    
    public static void main(String[] args) {
        int scaleFactor = 1;
        
        if (args.length > 0) {
            try {
                scaleFactor = Integer.parseInt(args[0]);
                if (scaleFactor <= 0) scaleFactor = 1;
            } catch (NumberFormatException e) {
                System.err.println("Invalid scale factor. Using default 1.");
                scaleFactor = 1;
            }
        }
        
        double totalTime = 0.0;
        
        totalTime += allocationPatternsTest(10000 * scaleFactor);
        totalTime += gcStressTest(4, 2500 * scaleFactor);
        totalTime += cacheLocalityTest(5000 * scaleFactor);
        totalTime += memoryPoolTest(8000 * scaleFactor);
        totalTime += memoryIntensiveTest(100 * scaleFactor);
        
        System.out.printf("%.3f%n", totalTime);
    }
}