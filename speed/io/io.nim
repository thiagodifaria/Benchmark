import times
import os
import strutils
import random
import json
import memfiles

# sequential text read reading a file line-by-line
proc sequentialReadTest(filename: string): float =
  let start = epochTime()
  var wordCount = 0
  try:
    for line in lines(filename):
      wordCount += line.split().len
  except IOError:
    stderr.writeLine("error: could not read file -> ", filename)
    return 0.0

  let finish = epochTime()
  # keep the result alive
  var dummyResult = wordCount
  discard dummyResult
  return (finish - start) * 1000

# random access read jump around in a binary file
proc randomAccessTest(filename: string, numAccesses: int): float =
  let start = epochTime()
  var totalBytesRead = 0
  var f: File
  try:
    f = syncio.open(filename, fmRead)
  except IOError:
    stderr.writeLine("error: could not open file -> ", filename)
    return 0.0
  
  defer: f.close()
  
  let fileSize = getFileSize(filename)
  if fileSize < 4096:
    stderr.writeLine("error: binary file too small -> ", filename)
    return 0.0

  # keep it predictable
  var rng = initRand(42)
  var buffer = newString(4096)
  
  for i in 0..<numAccesses:
    let offset = rng.rand(fileSize - 4096)
    f.setFilePos(offset)
    let bytesRead = f.readChars(toOpenArray(buffer, 0, 4095))
    totalBytesRead += bytesRead
  
  let finish = epochTime()
  var dummyResult = totalBytesRead
  discard dummyResult
  return (finish - start) * 1000

# memory-mapped read using the standard memfiles module
proc memoryMapTest(filename: string): float =
  let start = epochTime()
  var wordCount = 0
  var mf: MemFile
  try:
    mf = memfiles.open(filename, fmRead)
    # once mapped, we can copy it into a string
    let dataStr = cast[string](newString(mf.size))
    copyMem(addr dataStr[0], mf.mem, mf.size)
    wordCount = dataStr.split().len
    mf.close()
  except IOError:
    stderr.writeLine("error: could not map file -> ", filename)
    return 0.0

  let finish = epochTime()
  var dummyResult = wordCount
  discard dummyResult
  return (finish - start) * 1000

# csv read and process with a simple manual parser
proc csvReadAndProcessTest(filename: string): float =
  let start = epochTime()
  var priceSum = 0.0
  var filterCount = 0
  var firstLine = true
  try:
    for line in lines(filename):
      if firstLine:
        firstLine = false
        continue

      let parts = line.split(',')
      if parts.len >= 4:
        try:
          priceSum += parseFloat(parts[2])
        except ValueError:
          # just skip bad lines
          discard
        
        if parts[3] == "Electronics":
          filterCount += 1
  except IOError:
    stderr.writeLine("error: could not read csv -> ", filename)
    return 0.0
  
  let finish = epochTime()
  var sumResult = priceSum + float(filterCount)
  discard sumResult
  return (finish - start) * 1000

# generate and write a bunch of records to a csv file
proc csvWriteTest(filename: string, numRecords: int): float =
  let start = epochTime()
  var f: File
  try:
    f = syncio.open(filename, fmWrite)
  except IOError:
    stderr.writeLine("error: could not write csv -> ", filename)
    return 0.0
  defer: f.close()
  
  f.writeLine("id,product_name,price,category")
  for i in 0..<numRecords:
    let price = formatFloat(float(i) * 1.5, ffDecimal, 2)
    f.writeLine(i, ",Product-", i, ",", price, ",Category-", i mod 10)
  
  let finish = epochTime()
  return (finish - start) * 1000

# json dom read and process loading the whole file into a jsonnode
proc jsonDomReadAndProcessTest(filename: string): float =
  let start = epochTime()
  var userId = ""
  try:
    let fileContent = readFile(filename)
    let data = parseJson(fileContent)
    userId = data["metadata"]["user_id"].getStr("")
  except CatchableError:
    stderr.writeLine("error: could not read or parse json -> ", filename)
    return 0.0

  let finish = epochTime()
  var userIdLen = userId.len
  discard userIdLen
  return (finish - start) * 1000

# json streaming read for huge files, assumes json lines
proc jsonStreamReadAndProcessTest(filename: string): float =
  let start = epochTime()
  var total = 0.0
  try:
    for line in lines(filename):
      if line.len == 0: continue
      try:
        let obj = parseJson(line)
        if "price" in obj:
          total += obj["price"].getFloat(0.0)
        else:
          total += 0.0
      except JsonParsingError:
        # skip bad lines
        discard
  except IOError:
    stderr.writeLine("error: could not stream json -> ", filename)
    return 0.0
  
  let finish = epochTime()
  var totalResult = total
  discard totalResult
  return (finish - start) * 1000

# build a big nim json object and dump it to a file
proc jsonWriteTest(filename: string, numRecords: int): float =
  let start = epochTime()
  
  var items = newJArray()
  for i in 0..<numRecords:
    items.add(%*{"id": i, "name": "Item " & $i, "attributes": {"active": true, "value": float(i) * 3.14}})

  let data = %*{"metadata": {"record_count": numRecords}, "items": items}
  
  try:
    writeFile(filename, $data)
  except IOError:
    stderr.writeLine("error: could not write json -> ", filename)
    return 0.0

  let finish = epochTime()
  return (finish - start) * 1000


when isMainModule:
  var scaleFactor = 1
  if paramCount() > 0:
    try:
      scaleFactor = parseInt(paramStr(1))
    except ValueError:
      stderr.writeLine("invalid scale factor, using default 1")

  let textFile = "data.txt"
  let binFile = "data.bin"
  let csvReadFile = "data.csv"
  let csvWriteFile = "output.csv"
  let jsonDomFile = "data.json"
  let jsonStreamFile = "data_large.jsonl"
  let jsonWriteFile = "output.json"

  let randomAccesses = 1000 * scaleFactor
  let csvWriteRecords = 100000 * scaleFactor
  let jsonWriteRecords = 50000 * scaleFactor

  var totalTime = 0.0

  totalTime += sequentialReadTest(textFile)
  totalTime += randomAccessTest(binFile, randomAccesses)
  totalTime += memoryMapTest(textFile)
  totalTime += csvReadAndProcessTest(csvReadFile)
  totalTime += csvWriteTest(csvWriteFile, csvWriteRecords)
  totalTime += jsonDomReadAndProcessTest(jsonDomFile)
  totalTime += jsonStreamReadAndProcessTest(jsonStreamFile)
  totalTime += jsonWriteTest(jsonWriteFile, jsonWriteRecords)

  echo formatFloat(totalTime, ffDecimal, 3)