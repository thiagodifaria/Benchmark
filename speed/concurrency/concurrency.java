import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.List;
import java.util.ArrayList;

public class concurrency {

    // parallel http requests test
    static double parallelHttpTest(int numRequests) {
        long start = System.nanoTime();
        
        ExecutorService executor = Executors.newFixedThreadPool(Math.min(numRequests, 50));
        AtomicInteger successful = new AtomicInteger(0);
        CountDownLatch latch = new CountDownLatch(numRequests);
        
        for (int i = 0; i < numRequests; i++) {
            executor.submit(() -> {
                try {
                    URL url = new URL("http://127.0.0.1:8000/fast");
                    HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                    conn.setRequestMethod("GET");
                    conn.setConnectTimeout(5000);
                    conn.setReadTimeout(5000);
                    
                    int responseCode = conn.getResponseCode();
                    if (responseCode == 200) {
                        // read response to simulate real usage
                        try (BufferedReader reader = new BufferedReader(
                                new InputStreamReader(conn.getInputStream()))) {
                            while (reader.readLine() != null) {
                                // consume response
                            }
                        }
                        successful.incrementAndGet();
                    }
                    conn.disconnect();
                } catch (Exception e) {
                    // ignore errors for benchmark
                } finally {
                    latch.countDown();
                }
            });
        }
        
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        executor.shutdown();
        
        long end = System.nanoTime();
        int result = successful.get(); // prevent optimization
        return (end - start) / 1_000_000.0;
    }

    // producer-consumer queue test using BlockingQueue
    static double producerConsumerTest(int numPairs, int itemsPerThread) {
        long start = System.nanoTime();
        
        BlockingQueue<Integer> queue = new ArrayBlockingQueue<>(1000);
        AtomicInteger processed = new AtomicInteger(0);
        ExecutorService executor = Executors.newFixedThreadPool(numPairs * 2);
        CountDownLatch latch = new CountDownLatch(numPairs * 2);
        
        // create producer threads
        for (int i = 0; i < numPairs; i++) {
            final int producerId = i;
            executor.submit(() -> {
                try {
                    for (int j = 0; j < itemsPerThread; j++) {
                        queue.put(producerId * 1000 + j);
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    latch.countDown();
                }
            });
        }
        
        // create consumer threads
        for (int i = 0; i < numPairs; i++) {
            executor.submit(() -> {
                try {
                    for (int j = 0; j < itemsPerThread; j++) {
                        int item = queue.take();
                        
                        // simulate processing
                        int dummy = item * item;
                        
                        processed.incrementAndGet();
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    latch.countDown();
                }
            });
        }
        
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        executor.shutdown();
        
        long end = System.nanoTime();
        int result = processed.get(); // prevent optimization
        return (end - start) / 1_000_000.0;
    }

    // fibonacci computation
    static long fibonacci(int n) {
        if (n <= 1) return n;
        
        long a = 0, b = 1;
        for (int i = 2; i <= n; i++) {
            long temp = a + b;
            a = b;
            b = temp;
        }
        return b;
    }

    // parallel mathematical work test
    static double parallelMathTest(int numThreads, int workPerThread) {
        long start = System.nanoTime();
        
        ExecutorService executor = Executors.newFixedThreadPool(numThreads);
        AtomicLong totalSum = new AtomicLong(0);
        CountDownLatch latch = new CountDownLatch(numThreads);
        
        for (int i = 0; i < numThreads; i++) {
            final int workerId = i;
            executor.submit(() -> {
                long localSum = 0;
                
                for (int j = 0; j < workPerThread; j++) {
                    localSum += fibonacci(35);
                    
                    // additional mathematical work
                    for (int k = 0; k < 1000; k++) {
                        localSum += k * k;
                    }
                }
                
                totalSum.addAndGet(localSum);
                latch.countDown();
            });
        }
        
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        executor.shutdown();
        
        long end = System.nanoTime();
        long result = totalSum.get(); // prevent optimization
        return (end - start) / 1_000_000.0;
    }

    // async file processing test
    static double asyncFileTest(int numFiles) {
        long start = System.nanoTime();
        
        Path tempDir;
        try {
            tempDir = Files.createTempDirectory("concurrency_test");
        } catch (IOException e) {
            return 0.0;
        }
        
        ExecutorService executor = Executors.newFixedThreadPool(Math.min(numFiles, 20));
        AtomicInteger processed = new AtomicInteger(0);
        CountDownLatch latch = new CountDownLatch(numFiles);
        
        for (int i = 0; i < numFiles; i++) {
            final int fileId = i;
            executor.submit(() -> {
                try {
                    Path filePath = tempDir.resolve("test_" + fileId + ".dat");
                    
                    // write file
                    try (PrintWriter writer = new PrintWriter(Files.newBufferedWriter(filePath))) {
                        for (int j = 0; j < 1000; j++) {
                            writer.println("data_" + fileId + "_" + j);
                        }
                    }
                    
                    // read and process file
                    List<String> lines = Files.readAllLines(filePath);
                    
                    // simulate processing
                    int lineCount = 0;
                    for (String line : lines) {
                        lineCount++;
                        // volatile access to prevent optimization
                        int len = line.length();
                    }
                    
                    if (lineCount > 0) {
                        processed.incrementAndGet();
                    }
                    
                    // cleanup
                    Files.deleteIfExists(filePath);
                    
                } catch (IOException e) {
                    // ignore errors for benchmark
                } finally {
                    latch.countDown();
                }
            });
        }
        
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        executor.shutdown();
        
        // cleanup temp directory
        try {
            Files.deleteIfExists(tempDir);
        } catch (IOException e) {
            // ignore cleanup errors
        }
        
        long end = System.nanoTime();
        int result = processed.get(); // prevent optimization
        return (end - start) / 1_000_000.0;
    }

    // thread pool performance test
    static double threadPoolTest(int poolSize, int totalTasks) {
        long start = System.nanoTime();
        
        ThreadPoolExecutor executor = new ThreadPoolExecutor(
            poolSize, poolSize, 0L, TimeUnit.MILLISECONDS,
            new LinkedBlockingQueue<>()
        );
        
        AtomicInteger completed = new AtomicInteger(0);
        CountDownLatch latch = new CountDownLatch(totalTasks);
        
        for (int i = 0; i < totalTasks; i++) {
            final int taskId = i;
            executor.submit(() -> {
                try {
                    // simulate varied workload
                    long work = 0;
                    for (int j = 0; j < 10000; j++) {
                        work += j * j;
                    }
                    
                    Thread.sleep(0, 100_000); // 100 microseconds
                    completed.incrementAndGet();
                    
                    // prevent optimization
                    if (work == -1) System.out.println("impossible");
                    
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    latch.countDown();
                }
            });
        }
        
        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        executor.shutdown();
        
        long end = System.nanoTime();
        int result = completed.get(); // prevent optimization
        return (end - start) / 1_000_000.0;
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

        totalTime += parallelHttpTest(50 * scaleFactor);
        totalTime += producerConsumerTest(4, 1000 * scaleFactor);
        totalTime += parallelMathTest(4, 100 * scaleFactor);
        totalTime += asyncFileTest(20 * scaleFactor);
        totalTime += threadPoolTest(8, 500 * scaleFactor);

        System.out.printf("%.3f%n", totalTime);
    }
}