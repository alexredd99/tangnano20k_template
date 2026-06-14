`timescale 1ns / 1ps
`default_nettype none

// Crude behavioral wrapper for rPLL
// Replace with `rPLL` cell in Yosys (chtype -map gowin_rPLL rPLL)
// (workaround for https://github.com/povik/yosys-slang/issues/296)
(* blackbox *)
module gowin_rPLL #(
    parameter string       FCLKIN        = "100.0",  // frequency of CLKIN
    parameter string       DYN_IDIV_SEL  = "false",  // true:IDSEL, false:IDIV_SEL
    parameter int unsigned IDIV_SEL      = 0,        // 0:1, 1:2 ... 63:64
    parameter string       DYN_FBDIV_SEL = "false",  // true:FBDSEL, false:FBDIV_SEL
    parameter int unsigned FBDIV_SEL     = 0,        // 0:1, 1:2 ... 63:64
    parameter string       DYN_ODIV_SEL  = "false",  // true:ODSEL, false:ODIV_SEL
    parameter int unsigned ODIV_SEL      = 8,        // 2/4/8/16/32/48/64/80/96/112/128

    parameter string PSDA_SEL   = "0000",
    parameter string DYN_DA_EN  = "false",  // true:PSDA or DUTYDA or FDA, false: DA_SEL
    parameter string DUTYDA_SEL = "1000",

    parameter bit          CLKOUT_FT_DIR    = 1'b1,  // CLKOUT fine tuning direction. 1'b1 only
    parameter bit          CLKOUTP_FT_DIR   = 1'b1,  // 1'b1 only
    parameter int unsigned CLKOUT_DLY_STEP  = 0,     // 0, 1, 2, 4
    parameter int unsigned CLKOUTP_DLY_STEP = 0,     // 0, 1, 2

    parameter string       CLKFB_SEL      = "internal",  // "internal", "external"
    parameter string       CLKOUT_BYPASS  = "false",     // "true", "false"
    parameter string       CLKOUTP_BYPASS = "false",     // "true", "false"
    parameter string       CLKOUTD_BYPASS = "false",     // "true", "false"
    parameter int unsigned DYN_SDIV_SEL   = 2,           // 2~128, only even numbers
    parameter string       CLKOUTD_SRC    = "CLKOUT",    // CLKOUT, CLKOUTP
    parameter string       CLKOUTD3_SRC   = "CLKOUT",    // CLKOUT, CLKOUTP
    parameter string       DEVICE         = "GW2A-18"
) (
    output logic       CLKOUT,
    output logic       CLKOUTP,
    output logic       CLKOUTD,
    output logic       CLKOUTD3,
    output logic       LOCK,
    input  logic       CLKIN,
    input  logic       CLKFB,
    input  logic [5:0] FBDSEL,
    input  logic [5:0] IDSEL,
    input  logic [5:0] ODSEL,
    input  logic [3:0] DUTYDA,
    input  logic [3:0] PSDA,
    input  logic [3:0] FDLY,
    input  logic       RESET,
    input  logic       RESET_P
);
`ifndef SYNTHESIS
  // Crude approximation of PLL behavior

  string FreqInMHz = FCLKIN;
  real FreqOutMHz = (FreqInMHz.atoreal() * $itor(FBDIV_SEL + 1)) / $itor(IDIV_SEL + 1);
  realtime ClkPeriodNs = 1000.0 / FreqOutMHz;

  initial begin
    CLKOUT = 0;
    forever #(ClkPeriodNs / 2) CLKOUT = ~CLKOUT;
  end

  // Simulate PLL lock
  initial begin
    LOCK = 0;
    repeat (100) @(posedge CLKIN);
    LOCK = 1;
  end
`endif  // SYNTHESIS

endmodule : gowin_rPLL
