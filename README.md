# Comprehensive Speed (only for now) Benchmark Suite

what's up this is my attempt at creating a "comprehensive" programming language benchmark, i say "comprehensive" in quotes because honestly, i'm still figuring this stuff out as i go lol.

## What This Thing Does

Basically, i got curious about which programming language is actually better, so i decided to build this benchmark suite that tests languages across different areas, but for now only in speed "spectrum":

- **Mathematical stuff** - Matrix operations, prime numbers, statistics, FFT, data structures
- **I/O operations** - File reading, CSV processing, JSON parsing 
- **Memory management** - Allocation patterns, garbage collection stress, cache locality

Right now it tests: C, C++, Go, Java, Julia, Nim, Python, and Rust.

## How to Run It

```bash
cd speed
./speed.sh [scale_factor]
```

Scale factor goes from 1 (light) to 5 (intensive). Default is 3.

## Current Results (Scale Factor 3)

### Mathematical Performance
1. **Rust** 🥇 - Total domination
2. **C** - 1.68x slower (solid)
3. **Go** - 1.97x slower
4. **C++** - 2.35x slower
5. **Nim** - 2.55x slower
6. **Java** - 9x slower (ouch)
7. **Python** - 38x slower (expected)
8. **Julia** - 47x slower (wtf?)

### I/O Performance  
1. **Nim** 🥇 - Absolute monster at I/O
2. **C** - 63x slower
3. **Go** - 71x slower  
4. **C++** - 116x slower
5. **Java** - 220x slower
6. **Julia** - 266x slower (wtf?)
7. **Python** - 318x slower
8. **Rust** - 2408x slower (I definitely screwed something up here)

### Memory Management
1. **Rust** 🥇 - Back on top
2. **C** - 1.04x slower (basically tied)
3. **C++** - 1.17x slower
4. **Go** - 1.29x slower
5. **Nim** - 2.08x slower
6. **Java** - 2.64x slower
7. **Python** - 24x slower
8. **Julia** - 41x slower (...)

## Known Issues (aka My Screw-ups)

There are definitely problems with my implementations:

1. **Rust I/O is catastrophically slow** - Like 2400x slower than Nim slow. I clearly don't know how to do I/O properly in Rust yet. This is 100% my fault, not Rust's.

2. **Julia having issues** - It's consistently underperforming across all benchmarks. Could be my JIT warmup, could be my algorithms, could be I just don't understand Julia well enough.

3. **Some results seem sus** - When you see numbers that don't make intuitive sense, it's probably because I implemented something wrong or made a rookie mistake.

4. **Not production-quality code** - I'm learning as I go, so the implementations might not be using best practices for each language.

## Why You Should Take This With a Grain of Salt

I'm basically a beginner/enthusiast trying to learn about performance and programming languages. I started this project to satisfy my own curiosity, but I know I'm making mistakes along the way. 

The results you see here are more about my current skill level than the actual performance characteristics of these languages. Professional benchmarks are done by people way smarter than me with way more experience.

## What I'm Learning

This project is teaching me a ton about:
- How different languages handle memory
- Compiler optimizations  
- I/O patterns
- Multi-threading
- Algorithm implementation across different paradigms

## Future Plans

I'm gonna keep working on this and trying to improve:

1. **Fix the obvious problems** - Starting with that Rust I/O disaster
2. **Better implementations** - As I learn more about each language
3. **More test cases** - Add network performance, database operations, etc.
4. **Better documentation** - Explain what each test actually does
5. **Code cleanup** - Make it less of a mess

My goal is to eventually have something that's actually professional-quality instead of this "learning in public" mess you see now.

## A Request for Patience

If you're someone who actually knows what they're doing and you see glaring issues in my code, please be patient with me! I know I'm not doing everything right, but I'm trying to learn. Feel free to point out issues or suggest improvements. I'm genuinely trying to get better at this stuff.

## Current Project Status

This is very much a work-in-progress. I'm planning to do a major cleanup phase at the end where I'll:
- Reorganize all the files and folders properly (or not)
- Write proper documentation
- Fix the implementations that are obviously wrong
- Make everything consistent and professional-looking
- Write a proper README

But for now, this is what i got, it's probably wrong in places, but it's honest about what it is.

---

*Built with confusion, determination, and way too much coffee ☕*