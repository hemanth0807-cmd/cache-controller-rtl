# Simulation Notes

## Vivado / XSIM

1. Open `cache_controller.xpr` in Vivado.
2. Confirm `tb_cache_controller.sv` is selected as the simulation top.
3. Run behavioral simulation.

## Scripted Simulation

The ordered sources are listed in `filelist.f`. Use this file with a SystemVerilog-capable simulator, or import the files in the listed order.

The testbench exercises CPU-facing cache accesses and main-memory response behavior.
