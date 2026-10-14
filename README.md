# Cache Controller RTL

Parameterized write-back cache controller implemented in SystemVerilog.

## Project Contents

- `cache_controller.srcs/sources_1/new/cache_controller.sv` - cache controller FSM and CPU/main-memory interface logic.
- `cache_controller.srcs/sources_1/new/cache_memory.sv` - cache line, tag, valid, and dirty storage.
- `cache_controller.srcs/sim_1/new/tb_cache_controller.sv` - behavioral testbench.
- `cache_controller.xpr` - Vivado project file.
- `filelist.f` - ordered source list for simulators or scripted builds.

## Design Notes

The controller accepts CPU read/write requests and communicates with main memory using full cache-line transfers. The FSM includes lookup, writeback, refill, and response states. Cache metadata includes valid and dirty bits.

Default parameters:

- `ADDR_WIDTH = 32`
- `CPU_DATA_WIDTH = 32`
- `LINE_SIZE = 128`
- `NUM_LINES = 64`

## Simulation

See `docs/SIMULATION.md` for simulation guidance.
