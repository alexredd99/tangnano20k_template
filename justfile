# Tools
_gowin_pack         := require("gowin_pack")
_jq                 := require("jq")
_nextpnr_himbaechel := require("nextpnr-himbaechel")
_openfpga_loader    := require("openFPGALoader")
_tee                := require("tee")
_verilator          := require("verilator")
_yosys              := require("yosys")
_yosys_config       := require("yosys-config")

# Paths
_script_dir    := justfile_directory() / "scripts"
_build_dir     := justfile_directory() / "build"
_hardware_dir  := justfile_directory() / "hardware"
_rtl_dir       := _hardware_dir / "rtl"
_testbench_dir := _hardware_dir / "testbench"
_simcells_dir  := shell(_yosys_config + " " + join("--datdir", "gowin"))

_default:
  @just --list

_prep:
  mkdir -p {{_build_dir}}

[working-directory: 'build']
_sim_behavioral testbench: _prep
  {{_verilator}} \
    --binary \
    --relative-includes \
    -Wno-fatal \
    --top-module {{testbench}} \
    {{_testbench_dir / testbench + ".sv"}} \
  && {{join("obj_dir", "V" + testbench)}}


[working-directory: 'build']
_sim_post_synth testbench: _prep
  {{_verilator}} \
    --binary \
    --relative-includes \
    -Wno-fatal \
    -Wno-ASSIGNIN \
    --top-module {{testbench}} \
    +define+POST_SYNTH_SIM \
    {{_simcells_dir / "cells_sim.v"}} \
    {{_rtl_dir / "common" / "gowin_rPLL.sv"}} \
    {{_testbench_dir / testbench + ".sv"}} \
    1_synth_netlist.v \
  && {{join("obj_dir", "V" + testbench)}}

# Design
[group("Simulation")]
[working-directory: 'build']
simulate testbench="top_tb" post_synth="false": _prep
  just \
    {{ if post_synth == "false" {"_sim_behavioral"} else {"_sim_post_synth"} }} \
    {{testbench}}

# Run design synthesis
[group("Synthesis")]
[working-directory: 'build']
synthesize: _prep
  {{_yosys}} -D SYNTHESIS -c {{_script_dir / "synth.tcl"}} -- \
      --family "gw2a" \
      --top "top" \
      --json_netlist "1_synth_netlist.json" \
      --verilog_netlist "1_synth_netlist.v" \
      {{_rtl_dir / "top.sv"}} 2>&1 \
  | {{_tee}} "1_yosys.log"

[group("Synthesis")]
[working-directory: 'build']
place_and_route: synthesize
  {{_nextpnr_himbaechel}} \
      --json "1_synth_netlist.json" \
      --top "top" \
      --freq 100 \
      --write "2_pnr_netlist.json" \
      --placed-svg "2_placement.svg" \
      --routed-svg "2_routing.svg" \
      --device "GW2AR-LV18QN88C8/I7" \
      --vopt family="GW2A-18C" \
      --vopt cst={{_hardware_dir / "constraints.cst"}} \
      --report "tmp.json" \
      --detailed-timing-report 2>&1 \
  | {{_tee}} "2_place_and_route.log"
  # nextpnr-himbaechel outputs unformatted report by default
  {{_jq}} . "tmp.json" > "2_pnr_report.json"
  rm "tmp.json"

[group("Synthesis")]
[working-directory: 'build']
pack_bitstream: place_and_route
  {{_gowin_pack}} \
      --device "GW2AR-LV18QN88C8/I7" \
      --output "3_bitstream.fs" \
      "2_pnr_netlist.json"

# flash: false = program SRAM, true = actually flash bitstream
[group("Programming")]
[working-directory: 'build']
program flash="true":
  {{_openfpga_loader}} \
      {{if flash == "true" {"-f"} else {""} }} \
      --cable ft2232 \
      --bitstream "3_bitstream.fs"

synth_all: pack_bitstream
run_all: pack_bitstream program

clean:
  rm -rf {{_build_dir}}
