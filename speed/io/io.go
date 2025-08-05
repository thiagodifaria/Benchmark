package main

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"strconv"
	"strings"
	"time"
)

// sequential text read reads a file line-by-line
func sequentialReadTest(filename string) float64 {
	start := time.Now()

	file, err := os.Open(filename)
	if err != nil {
		log.Printf("error: could not open file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	wordCount := 0
	for scanner.Scan() {
		wordCount += len(strings.Fields(scanner.Text()))
	}

	if err := scanner.Err(); err != nil {
		log.Printf("error: reading file -> %s", filename)
	}

	end := time.Now()
	// keep the result alive
	_ = wordCount
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// random access read jumps around in a binary file
func randomAccessTest(filename string, numAccesses int) float64 {
	start := time.Now()

	file, err := os.Open(filename)
	if err != nil {
		log.Printf("error: could not open file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	info, err := file.Stat()
	if err != nil {
		log.Printf("error: could not get file info -> %s", filename)
		return 0.0
	}

	fileSize := info.Size()
	if fileSize < 4096 {
		log.Printf("error: binary file too small -> %s", filename)
		return 0.0
	}

	// keep it predictable
	rng := rand.New(rand.NewSource(42))
	buffer := make([]byte, 4096)
	totalBytesRead := 0

	for i := 0; i < numAccesses; i++ {
		offset := rng.Int63n(fileSize - 4096)
		// readat is great for this, no need to seek first
		bytesRead, err := file.ReadAt(buffer, offset)
		if err != nil && err != io.EOF {
			log.Printf("error: reading at offset -> %v", err)
			continue
		}
		totalBytesRead += bytesRead
	}

	end := time.Now()
	_ = totalBytesRead
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// buffered read for large files
// go doesn't have a standard mmap, so we use a heavily buffered scanner instead
// this is the idiomatic go way to process large files fast
func bufferedReadTest(filename string) float64 {
	start := time.Now()

	file, err := os.Open(filename)
	if err != nil {
		log.Printf("error: could not open file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	// give it a big buffer to chew on
	const maxCapacity = 1024 * 1024
	buf := make([]byte, maxCapacity)
	scanner.Buffer(buf, maxCapacity)

	wordCount := 0
	for scanner.Scan() {
		wordCount += len(strings.Fields(scanner.Text()))
	}

	end := time.Now()
	_ = wordCount
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// csv read and process using the standard library
func csvReadAndProcessTest(filename string) float64 {
	start := time.Now()

	file, err := os.Open(filename)
	if err != nil {
		log.Printf("error: could not open file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	reader := csv.NewReader(file)
	// skip header
	_, err = reader.Read()
	if err != nil {
		log.Printf("error: could not read csv header -> %v", err)
		return 0.0
	}

	priceSum := 0.0
	filterCount := 0
	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue // just skip bad lines
		}

		// record[2] is price
		price, err := strconv.ParseFloat(record[2], 64)
		if err == nil {
			priceSum += price
		}

		// record[3] is category
		if len(record) > 3 && record[3] == "Electronics" {
			filterCount++
		}
	}

	end := time.Now()
	_ = priceSum + float64(filterCount)
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// generate and write a bunch of records to a csv file
func csvWriteTest(filename string, numRecords int) float64 {
	start := time.Now()

	file, err := os.Create(filename)
	if err != nil {
		log.Printf("error: could not create file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	writer := csv.NewWriter(file)
	defer writer.Flush() // flush makes sure everything is written to disk

	writer.Write([]string{"id", "product_name", "price", "category"})
	for i := 0; i < numRecords; i++ {
		row := []string{
			strconv.Itoa(i),
			fmt.Sprintf("Product-%d", i),
			fmt.Sprintf("%.2f", float64(i)*1.5),
			fmt.Sprintf("Category-%d", i%10),
		}
		writer.Write(row)
	}

	end := time.Now()
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// json dom read and process loads the whole file into memory
func jsonDomReadAndProcessTest(filename string) float64 {
	start := time.Now()

	file, err := os.ReadFile(filename)
	if err != nil {
		log.Printf("error: could not read file -> %s", filename)
		return 0.0
	}

	var data map[string]any
	json.Unmarshal(file, &data)

	// navigate the map to get the data
	var userId string
	if metadata, ok := data["metadata"].(map[string]any); ok {
		if id, ok := metadata["user_id"].(string); ok {
			userId = id
		}
	}

	end := time.Now()
	_ = len(userId)
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// json streaming read for huge files using a json decoder
// assumes a json lines format (.jsonl)
func jsonStreamReadAndProcessTest(filename string) float64 {
	start := time.Now()

	file, err := os.Open(filename)
	if err != nil {
		log.Printf("error: could not open file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	total := 0.0
	for {
		var obj map[string]any
		if err := decoder.Decode(&obj); err == io.EOF {
			break
		} else if err != nil {
			continue // skip bad lines
		}

		if price, ok := obj["price"].(float64); ok {
			total += price
		}
	}

	end := time.Now()
	_ = total
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

// build a big go struct/map and dump it to a json file
func jsonWriteTest(filename string, numRecords int) float64 {
	start := time.Now()

	// defining a struct is more idiomatic and often faster in go
	type Item struct {
		ID         int               `json:"id"`
		Name       string            `json:"name"`
		Attributes map[string]any `json:"attributes"`
	}
	type Data struct {
		Metadata map[string]int `json:"metadata"`
		Items    []Item         `json:"items"`
	}

	data := Data{
		Metadata: map[string]int{"record_count": numRecords},
		Items:    make([]Item, numRecords),
	}

	for i := 0; i < numRecords; i++ {
		data.Items[i] = Item{
			ID:   i,
			Name: fmt.Sprintf("Item %d", i),
			Attributes: map[string]any{
				"active": true,
				"value":  float64(i) * 3.14,
			},
		}
	}

	file, err := os.Create(filename)
	if err != nil {
		log.Printf("error: could not create file -> %s", filename)
		return 0.0
	}
	defer file.Close()

	// the json encoder streams output, which is memory efficient
	encoder := json.NewEncoder(file)
	encoder.Encode(data)

	end := time.Now()
	return float64(end.Sub(start).Microseconds()) / 1000.0
}

func main() {
	scaleFactor := 1
	if len(os.Args) > 1 {
		val, err := strconv.Atoi(os.Args[1])
		if err == nil {
			scaleFactor = val
		} else {
			log.Print("invalid scale factor, using default 1")
		}
	}

	text_file := "data.txt"
	bin_file := "data.bin"
	csv_read_file := "data.csv"
	csv_write_file := "output.csv"
	json_dom_file := "data.json"
	json_stream_file := "data_large.jsonl"
	json_write_file := "output.json"

	randomAccesses := 1000 * scaleFactor
	csvWriteRecords := 100000 * scaleFactor
	jsonWriteRecords := 50000 * scaleFactor

	var totalTime float64

	totalTime += sequentialReadTest(text_file)
	totalTime += randomAccessTest(bin_file, randomAccesses)
	totalTime += bufferedReadTest(text_file)
	totalTime += csvReadAndProcessTest(csv_read_file)
	totalTime += csvWriteTest(csv_write_file, csvWriteRecords)
	totalTime += jsonDomReadAndProcessTest(json_dom_file)
	totalTime += jsonStreamReadAndProcessTest(json_stream_file)
	totalTime += jsonWriteTest(json_write_file, jsonWriteRecords)

	fmt.Printf("%.3f\n", totalTime)
}