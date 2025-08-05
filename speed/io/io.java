import java.io.*;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

import com.google.gson.Gson;
import com.google.gson.stream.JsonReader;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVPrinter;
import org.apache.commons.csv.CSVRecord;

public class io {

    // sequential text read reads a file line-by-line
    static double sequentialReadTest(String filename) {
        long start = System.nanoTime();
        long wordCount = 0;
        try (BufferedReader reader = new BufferedReader(new FileReader(filename, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                wordCount += line.split("\\s+").length;
            }
        } catch (IOException e) {
            System.err.println("error: could not read file -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        long result = wordCount;
        return (end - start) / 1_000_000.0;
    }

    // random access read jumps around in a binary file
    static double randomAccessTest(String filename, int numAccesses) {
        long start = System.nanoTime();
        long totalBytesRead = 0;
        try (RandomAccessFile file = new RandomAccessFile(filename, "r")) {
            long fileSize = file.length();
            if (fileSize < 4096) {
                System.err.println("error: binary file too small -> " + filename);
                return 0.0;
            }
            Random rng = new Random(42);
            byte[] buffer = new byte[4096];
            for (int i = 0; i < numAccesses; i++) {
                long offset = rng.nextLong(fileSize - 4096);
                file.seek(offset);
                int bytesRead = file.read(buffer);
                if (bytesRead > 0) {
                    totalBytesRead += bytesRead;
                }
            }
        } catch (IOException e) {
            System.err.println("error: could not read file -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        long result = totalBytesRead;
        return (end - start) / 1_000_000.0;
    }
    
    // memory-mapped read uses nio filechannels
    static double memoryMapTest(String filename) {
        long start = System.nanoTime();
        long wordCount = 0;
        try (RandomAccessFile file = new RandomAccessFile(filename, "r");
             FileChannel channel = file.getChannel()) {
            MappedByteBuffer buffer = channel.map(FileChannel.MapMode.READ_ONLY, 0, channel.size());
            // once mapped, we can process it like one big byte array
            String content = StandardCharsets.UTF_8.decode(buffer).toString();
            wordCount = content.split("\\s+").length;
        } catch (IOException e) {
            System.err.println("error: could not map file -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        long result = wordCount;
        return (end - start) / 1_000_000.0;
    }

    // csv read and process using apache commons csv
    static double csvReadAndProcessTest(String filename) {
        long start = System.nanoTime();
        double priceSum = 0.0;
        int filterCount = 0;
        try (Reader in = new FileReader(filename, StandardCharsets.UTF_8)) {
            CSVParser parser = CSVFormat.DEFAULT.builder().setHeader().setSkipHeaderRecord(true).build().parse(in);
            for (CSVRecord record : parser) {
                try {
                    priceSum += Double.parseDouble(record.get("price"));
                    if ("Electronics".equals(record.get("category"))) {
                        filterCount++;
                    }
                } catch (NumberFormatException | IllegalStateException e) {
                    // just skip bad records
                    continue;
                }
            }
        } catch (IOException e) {
            System.err.println("error: could not read csv -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        double result = priceSum + filterCount;
        return (end - start) / 1_000_000.0;
    }

    // generate and write a bunch of records to a csv file
    static double csvWriteTest(String filename, int numRecords) {
        long start = System.nanoTime();
        String[] headers = {"id", "product_name", "price", "category"};
        try (Writer out = new FileWriter(filename, StandardCharsets.UTF_8);
             CSVPrinter printer = new CSVPrinter(out, CSVFormat.DEFAULT.builder().setHeader(headers).build())) {
            for (int i = 0; i < numRecords; i++) {
                printer.printRecord(i, "Product-" + i, String.format("%.2f", i * 1.5), "Category-" + (i % 10));
            }
        } catch (IOException e) {
            System.err.println("error: could not write csv -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        return (end - start) / 1_000_000.0;
    }

    // json dom read and process using gson to load the whole thing
    static double jsonDomReadAndProcessTest(String filename) {
        long start = System.nanoTime();
        String userId = "";
        Gson gson = new Gson();
        try (Reader reader = new FileReader(filename, StandardCharsets.UTF_8)) {
            Map<String, Object> data = gson.fromJson(reader, Map.class);
            // gson parses numbers as double by default, so we have to navigate the map carefully
            Map<String, Object> metadata = (Map<String, Object>) data.get("metadata");
            if (metadata != null) {
                userId = (String) metadata.get("user_id");
            }
        } catch (IOException e) {
            System.err.println("error: could not read json -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        int result = userId != null ? userId.length() : 0;
        return (end - start) / 1_000_000.0;
    }

    // json streaming read for huge files using gson's stream reader
    static double jsonStreamReadAndProcessTest(String filename) {
        long start = System.nanoTime();
        double total = 0.0;
        Gson gson = new Gson();
        try (JsonReader reader = new JsonReader(new FileReader(filename, StandardCharsets.UTF_8))) {
            // assumes a json lines format (.jsonl)
            while (reader.hasNext()) {
                try {
                    Map<String, Object> obj = gson.fromJson(reader, Map.class);
                    Object price = obj.get("price");
                    if (price instanceof Double) {
                        total += (Double) price;
                    }
                } catch(Exception e) {
                    // skip bad lines
                    if(reader.hasNext()) reader.skipValue();
                }
            }
        } catch (IOException e) {
            System.err.println("error: could not stream json -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        double result = total;
        return (end - start) / 1_000_000.0;
    }

    // build a big java map and dump it to a json file
    static double jsonWriteTest(String filename, int numRecords) {
        long start = System.nanoTime();
        Map<String, Object> data = new HashMap<>();
        data.put("metadata", Map.of("record_count", numRecords));
        List<Map<String, Object>> items = new ArrayList<>(numRecords);
        for (int i = 0; i < numRecords; i++) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", i);
            item.put("name", "Item " + i);
            item.put("attributes", Map.of("active", true, "value", i * 3.14));
            items.add(item);
        }
        data.put("items", items);

        Gson gson = new Gson();
        try (Writer writer = new FileWriter(filename, StandardCharsets.UTF_8)) {
            gson.toJson(data, writer);
        } catch (IOException e) {
            System.err.println("error: could not write json -> " + filename);
            return 0.0;
        }
        long end = System.nanoTime();
        return (end - start) / 1_000_000.0;
    }

    public static void main(String[] args) {
        int scaleFactor = 1;
        if (args.length > 0) {
            try {
                scaleFactor = Integer.parseInt(args[0]);
            } catch (NumberFormatException e) {
                System.err.println("invalid scale factor, using default 1");
            }
        }

        String textFile = "data.txt";
        String binFile = "data.bin";
        String csvReadFile = "data.csv";
        String csvWriteFile = "output.csv";
        String jsonDomFile = "data.json";
        String jsonStreamFile = "data_large.jsonl";
        String jsonWriteFile = "output.json";

        int randomAccesses = 1000 * scaleFactor;
        int csvWriteRecords = 100000 * scaleFactor;
        int jsonWriteRecords = 50000 * scaleFactor;

        double totalTime = 0;

        totalTime += sequentialReadTest(textFile);
        totalTime += randomAccessTest(binFile, randomAccesses);
        totalTime += memoryMapTest(textFile);
        totalTime += csvReadAndProcessTest(csvReadFile);
        totalTime += csvWriteTest(csvWriteFile, csvWriteRecords);
        totalTime += jsonDomReadAndProcessTest(jsonDomFile);
        totalTime += jsonStreamReadAndProcessTest(jsonStreamFile);
        totalTime += jsonWriteTest(jsonWriteFile, jsonWriteRecords);

        System.out.printf("%.3f%n", totalTime);
    }
}