# Direct-Mapped Cache Controller in SystemVerilog

## Overview

This project implements a **parameterized, direct-mapped cache controller** using SystemVerilog. The design supports a write-back write policy and a write-allocate miss policy, with a finite-state machine (FSM) managing cache lookups, dirty-line writebacks, cache-line refills, and CPU responses.

The cache controller interfaces with a CPU-side request interface and a main-memory interface that transfers one complete cache line per transaction. A self-checking testbench models multi-cycle main-memory latency and verifies the primary cache operations.

## Features

- Parameterized cache architecture
- Direct-mapped cache organization
- Write-back write policy
- Write-allocate miss policy
- Separate data, tag, valid, and dirty arrays
- Tag comparison and valid-bit-based hit detection
- Dirty-line eviction and writeback
- Complete cache-line refill on a miss
- 32-bit CPU read and write data interface
- Multi-cycle main-memory interface
- Five-state FSM for transaction control
- Self-checking SystemVerilog testbench

## Cache Architecture

The design uses the following default configuration:

| Parameter | Configuration |
|---|---:|
| CPU address width | 32 bits |
| CPU data width | 32 bits |
| Cache line size | 128 bits (16 bytes) |
| Number of cache lines | 64 |
| Total cache data capacity | 1 KB |
| Words per cache line | 4 × 32-bit words |
| Mapping technique | Direct-mapped |
| Write policy | Write-back |
| Miss policy | Write-allocate |

The cache data capacity is:

`64 lines × 16 bytes per line = 1024 bytes = 1 KB`

Each memory block maps to exactly one cache line. The index selects the cache entry, while the tag identifies the memory block currently stored in that entry.

### Address Breakdown

The 32-bit address is divided into three fields:

| Field | Width | Purpose |
|---|---:|---|
| Tag | 22 bits | Identifies the memory block |
| Index | 6 bits | Selects one of 64 cache lines |
| Offset | 4 bits | Selects a byte within a 16-byte cache line |

The offset supports four 32-bit word positions within each cache line. The implementation assumes aligned 32-bit CPU accesses; unaligned accesses and byte-level write strobes are not implemented.

## Design Architecture

The design consists of two main RTL modules.

### 1. `cache_controller`

The cache controller is the top-level design module. It coordinates CPU requests, cache lookups, memory transactions, and CPU responses.

Its responsibilities include:

- Capturing CPU requests in internal registers
- Extracting tag, index, and offset fields
- Detecting cache hits and misses
- Selecting the requested 32-bit word
- Updating cache data and metadata
- Writing back dirty cache lines before eviction
- Requesting cache-line refills from main memory
- Generating CPU response signals

### 2. `cache_memory`

The cache memory module implements the cache storage arrays:

- `data_array` — stores 128-bit cache lines
- `tag_array` — stores the tag associated with each line
- `valid_array` — indicates whether a cache entry contains a valid block
- `dirty_array` — indicates whether a cache line has been modified

The selected entry is read combinationally using the index. Cache-array writes occur synchronously on the rising clock edge. Reset clears the valid and dirty metadata bits.

## Cache Hit and Miss Logic

A cache hit occurs when the selected line is valid and its stored tag matches the requested tag.

Conceptually:

`hit = valid && (requested_tag == stored_tag)`

If the condition is false, the controller handles a cache miss.

### Read Hit

1. Select the cache line using the index.
2. Compare the requested tag with the stored tag and check the valid bit.
3. Select the requested 32-bit word using the offset.
4. Capture the data into the response register.
5. Assert `cpu_ready` in the response state.

A read hit does not require a main-memory transaction.

### Write Hit

1. Locate the requested cache line.
2. Modify only the selected 32-bit word.
3. Preserve the existing tag.
4. Keep the valid bit asserted.
5. Set the dirty bit.

With the write-back policy, main memory is not updated immediately on a write hit.

## Write Policy

### Write-Back

CPU writes update the cache. Modified lines are written back to main memory only when they are evicted.

The dirty bit identifies whether a valid cache line needs to be written back before replacement.

### Write-Allocate

On a write miss, the controller fetches the complete cache line from main memory, updates the requested word, and stores the modified line in the cache with its valid and dirty bits asserted.

## Finite-State Machine

The controller uses five states:

| State | Responsibility |
|---|---|
| `IDLE` | Wait for a CPU request and capture its address, operation, and write data |
| `LOOKUP` | Check the selected cache line for a hit or miss |
| `WRITEBACK` | Write a valid, dirty victim line to main memory |
| `REFILL` | Fetch the requested cache line and update the cache |
| `RESPOND` | Signal completion of the CPU transaction |

### State Transitions

- `IDLE → LOOKUP`: A CPU read or write request is accepted.
- `LOOKUP → RESPOND`: The request hits in the cache.
- `LOOKUP → REFILL`: A miss occurs and the selected line does not require writeback.
- `LOOKUP → WRITEBACK`: A miss occurs and the selected valid line is dirty.
- `WRITEBACK → REFILL`: Main memory completes the writeback.
- `REFILL → RESPOND`: Main memory supplies the requested line.
- `RESPOND → IDLE`: The CPU transaction completes.

The controller latches request information so that a multi-cycle memory transaction continues using the original CPU request even if the external inputs change.

## Main-Memory Interface

The memory interface transfers complete 128-bit cache lines.

### Refill Transaction

For a refill, the controller constructs a line-aligned address from the requested tag and index, with the offset set to zero.

When `mem_ready` is asserted, the controller captures the returned line and installs it in the cache.

For a read miss, the line is marked valid and clean. For a write miss, the requested word is modified before the line is stored and marked dirty.

### Writeback Transaction

When a miss would evict a valid dirty line, the controller writes the victim line to main memory before refilling the requested block.

The writeback address is reconstructed using the **stored victim tag**, the selected index, and a zero offset. The writeback data is the complete cache line.

Using the stored tag is essential because the writeback must update the old memory block, not the newly requested block.

## Verification

The design was tested using a self-checking SystemVerilog testbench, `tb_cache_controller`, with a behavioral main-memory model.

The memory model introduces a simulated three-clock-cycle latency for read and write transactions and provides `mem_ready` when each transaction completes.

### Directed Test Cases

| Test | Operation | Expected behavior |
|---|---|---|
| 1 | Read miss at `0x1008` | Fetch the line and return `0x33333333` |
| 2 | Read hit at `0x1004` | Return `0x22222222` without another memory read |
| 3 | Write hit at `0x1008` | Update the cached word to `0xDEADBEEF` |
| 4 | Read after write at `0x1008` | Return `0xDEADBEEF` from the cache |
| 5 | Conflict read at `0x1400` | Write back the dirty victim, then refill the requested line |
| 6 | Verify writeback | Confirm main memory contains `0xDEADBEEF` at `0x1008` after eviction |
| 7 | Clean conflict miss at `0x1804` | Refill without an unnecessary writeback |
| 8 | Read all four word offsets in the `0x1800` line | Verify the returned data and confirm cache hits |

### Verification Results

The directed simulation tests passed for the implemented scenarios, including:

- Read miss and subsequent read hit
- Write hit and read-after-write consistency
- Dirty conflict eviction and memory writeback
- Clean conflict miss without writeback
- Correct selection of all four 32-bit words in a cache line

The testbench also tracks the number of main-memory reads and writes to help identify unnecessary memory transactions.

These results establish functional behavior for the tested scenarios; they do not constitute exhaustive verification or measured silicon performance.

## Limitations

The current implementation focuses on a single outstanding CPU transaction and a simple behavioral memory interface.

The following features are outside the current verified scope:

- Set-associative or fully associative mapping
- Multiple outstanding CPU requests
- Burst protocols such as AXI
- Unaligned accesses and byte-level write strobes
- Replacement policies such as LRU
- Formal verification and constrained-random verification
- Synthesis-based area, timing, and power analysis

## Future Improvements

Potential extensions include:

- Add SystemVerilog Assertions (SVA) for FSM transitions, request stability, and cache invariants.
- Add functional coverage for hit/miss combinations, dirty eviction, and refill paths.
- Expand testing to randomized request sequences and additional address conflicts.
- Integrate a standard bus protocol such as AXI4-Lite.
- Explore set-associative caches and replacement policies.
- Run synthesis and static timing analysis to evaluate implementation cost and timing.

## Skills Demonstrated

- SystemVerilog RTL design
- Digital design and finite-state machines
- Cache organization and memory hierarchy
- Address decoding and tag comparison
- Write-back and write-allocate policies
- Sequential and combinational logic
- CPU–memory interface design
- Self-checking testbench development
- Functional simulation and debugging

## Conclusion

This project demonstrates the design and functional simulation of a parameterized direct-mapped cache controller. It brings together cache metadata management, CPU request handling, multi-cycle memory transactions, dirty-line writeback, and cache-line refill in a modular SystemVerilog implementation.
