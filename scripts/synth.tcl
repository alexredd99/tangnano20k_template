yosys -import
plugin -i slang
yosys -import

array set options {
  family          "gw2a"
  top_module      "top"
  json_netlist    "synth.json"
  verilog_netlist "synth.v"
  rtl_files       {}
}

# Parse command line arguments
for {set i 0} {$i < [llength $argv]} {incr i} {
  set arg [lindex $argv $i]

  switch -exact -- $arg {
    -f -
    --family {
      incr i
      set options(family) [lindex $argv $i]
    }
    -t -
    --top {
      incr i
      set options(top_module) [lindex $argv $i]
    }
    --json_netlist {
      incr i
      set options(json_netlist) [lindex $argv $i]
    }
    --verilog_netlist {
      incr i
      set options(verilog_netlist) [lindex $argv $i]
    }
    default {
      # Add to RTL files
      lappend options(rtl_files) $arg
    }
  }
}

# Read RTL
read_slang -top $options(top_module) {*}$options(rtl_files)
# Map rPLL behavioral wrapper `gowin_rPLL` to actual `rPLL` cell
chtype -map gowin_rPLL rPLL

# https://yosyshq.readthedocs.io/projects/yosys/en/latest/cmd/index_techlibs_gowin.html
# Malformed JSON netlist when using -vout directly
synth_gowin -family $options(family) -json $options(json_netlist)

# Map actual `rPLL` cell back to wrapper `gowin_rPLL` for simulation
chtype -map rPLL gowin_rPLL
write_verilog $options(verilog_netlist)
