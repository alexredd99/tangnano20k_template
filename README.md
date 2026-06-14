# Tang Nano 20K Template Project
Template project for [Sipeed Tang Nano 20K FPGA](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html).

This example contains a UART loopback which displays the lower 6 bits of the last received byte on the onboard LEDs and demonstrates the following:
- Instantiation of [rPLL](https://github.com/YosysHQ/apicula/wiki/PLL#rPLL) cell to multiply onboard clock from 27 to ~100MHz
- Using onboard [BL616](https://aithinker-static.oss-cn-shenzhen.aliyuncs.com/docs/_media_old/bl616_bl618_ds_en_2.5_open_.pdf) UART and connecting to Python script using [`pyserial`](https://github.com/pyserial/pyserial)
- Connecting soft UART controllers to extensible AXI-Stream design ([`blinky`](hardware/rtl/blinky.sv))
- Driving onboard LEDs
- Synthesis and PnR using open-source [Yosys](https://github.com/yosyshq/yosys) Gowin toolchain for onboard [GW2AR](https://www.gowinsemi.com/en/product/arora-ii-fpga/) FPGA
- Using the [`yosys-slang`](https://github.com/povik/yosys-slang) plugin to support SystemVerilog designs
- [Verilator](https://github.com/verilator/verilator) behavioral and post-synthesis simulation using Gowin [synth cells](https://github.com/YosysHQ/yosys/blob/main/techlibs/gowin/cells_sim.v)

## Requirements
- [just](https://github.com/casey/just)
- OSS CAD Suite (tested w/ [release 2026-06-14](https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2026-06-14))
- Python >= 3.10 (recommend using [uv](https://docs.astral.sh/uv/))

## Getting Started
TLDR; Run designs synthesis, place-and-route, and program USB-connected FPGA
```shell
just run_all
```

Or to just run everything up to bitstream generation (no programming)
```shell
just synth_all
```

To see all recipes and their usage: `just`

Run Python demo:
```shell
src/main.py -d <USB DEVICE PATH>
```

### Simulation (TODO)
- `just simulate <MODULE NAME> <POST SYNTHESIS SIMULATION = true/false>`
- Behavioral `just simulate top_tb <false>`
- Post-synthesis `just simulate top_tb true` (must run `just synthesize` first)

### Synthesis (TODO)
- Tool flow (yosys, nextpnr-himbaechel, etc)

## Notes
- [`gowin_rPLL`](hardware/rtl/common/gowin_rPLL.sv) is a wrapper for the actual Gowin [`rPLL`](https://github.com/YosysHQ/yosys/blob/main/techlibs/gowin/cells_sim.v#L1913) and contains a very basic PLL behavioral model. Because `yosys-slang` has [issues with parameterized blackboxes](https://github.com/povik/yosys-slang/issues/296) we map instances of `gowin_rPLL` to `rPLL` for synthesis and map them back (to `gowin_rPLL`) in the synthesized Verilog netlist for post-synthesis simulation (see [`synth.tcl`](scripts/synth.tcl)).
- By their nature, USB-serial adapters introduce some amount of communication latency due to USB-polling. Because the BL616 UART does not expose hardware flow control to the FPGA, it's very easy to overflow its receiver buffer if the design generates data too quickly. Essentially, the host machine may not be able to read from the BL616 quickly enough to avoid overflow. One workaround is to chunk data so that it aligns with the BL616's 32 byte buffers (see [`transmit_fast`](src/main.py#27))

## Structure (TODO)
```
├── README.md
├── hardware
│   ├── constraints.cst
│   ├── rtl
│   │   ├── blinky.sv
│   │   ├── blinky_uart.sv
│   │   ├── common
│   │   │   ├── axis_fifo.sv
│   │   │   ├── buffered_uart.sv
│   │   │   ├── gowin_rPLL.sv
│   │   │   ├── uart_rx.sv
│   │   │   └── uart_tx.sv
│   │   └── top.sv
│   └── testbench
│       ├── blinky_uart_tb.sv
│       ├── top_tb.sv
│       └── uart_tb_pkg.sv
├── justfile
├── pyproject.toml
├── scripts
│   └── synth.tcl
├── src
│   └── main.py
```
