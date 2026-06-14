`include "blinky_uart.sv"
`include "common/gowin_rPLL.sv"
`timescale 1ns / 1ps
`default_nettype none

module pll_100mhz (
    input  wire  clk_i,
    output logic clk_o,
    output logic locked_o
);
  // Generated with `gowin_pll -d GW2AR-LV18QN88C8/I7 -o 100`
  gowin_rPLL #(
      .FCLKIN   ("27"),
      .IDIV_SEL (6),     // -> PFD = 3.857142857142857 MHz (range: 3-500 MHz)
      .FBDIV_SEL(25),    // -> CLKOUT = 100.28571428571429 MHz (range: 3.90625-625 MHz)
      .ODIV_SEL (8)
  ) i_pll (
      .CLKOUTP (),
      .CLKOUTD (),
      .CLKOUTD3(),
      .RESET   (1'b0),
      .RESET_P (1'b0),
      .CLKFB   (1'b0),
      .FBDSEL  (6'b0),
      .IDSEL   (6'b0),
      .ODSEL   (6'b0),
      .PSDA    (4'b0),
      .DUTYDA  (4'b0),
      .FDLY    (4'b0),
      .CLKIN   (clk_i),    // 27 MHz
      .CLKOUT  (clk_o),    // 100.28571428571429 MHz
      .LOCK    (locked_o)
  );

endmodule : pll_100mhz


module top #(
    // UART Params
    parameter  int unsigned BaudRate    = 2_000_000,
    parameter  int unsigned RxFIFODepth = 32,
    parameter  int unsigned TxFIFODepth = 32,
    // Constant
    localparam int unsigned ClkFreqHz   = 100_000_000,  // 100 MHz
    localparam int unsigned NumLED      = 6,
    localparam int unsigned DataWidth   = 8
) (
    input  logic              clk_i,  // pin 4 (27 MHz)
    input  logic              rx_i,   // pin 70
    output logic              tx_o,   // pin 69
    output logic [NumLED-1:0] led_o   // pins 15-20
);
  logic clock, locked;
  pll_100mhz i_pll (
      .clk_i   (clk_i),
      .clk_o   (clock),
      .locked_o(locked)
  );

  wire reset = !locked;  // Hold reset until PLL stable
  blinky_uart #(
      .ClkFreqHz  (ClkFreqHz),
      .NumLED     (NumLED),
      .BaudRate   (BaudRate),
      .RxFIFODepth(RxFIFODepth),
      .TxFIFODepth(TxFIFODepth),
      .DataWidth  (DataWidth)
  ) i_blinky_uart (
      .clk_i(clock),
      .rst_i(reset),
      .rx_i (rx_i),
      .tx_o (tx_o),
      .led_o(led_o)
  );

endmodule : top
