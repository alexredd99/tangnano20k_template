`include "uart_tb_pkg.sv"
`ifndef POST_SYNTH_SIM
`include "../rtl/top.sv"
`endif  // POST_SYNTH_SIM

`timescale 1ns / 1ps
`default_nettype none

module top_tb #(
    localparam int unsigned ClkFreqHz    = 27_000_000,
    localparam int unsigned PLLClkFreqHz = 100_285_714,
    // UART Params
    parameter  int unsigned BaudRate     = 2_000_000,
    parameter  int unsigned RxFIFODepth  = 32,
    parameter  int unsigned TxFIFODepth  = 32,
    // Constant
    localparam int unsigned NumLED       = 6,
    localparam int unsigned DataWidth    = 8,
    // Derived
    localparam realtime     ClkPeriodNs  = 1e9 / ClkFreqHz,
    localparam int unsigned PulseWidth   = PLLClkFreqHz / BaudRate
);
  import uart_tb_pkg::*;

  logic clk_i = 0, rst_i = 1;
  initial forever #(ClkPeriodNs / 2) clk_i = ~clk_i;

  uart_if #(DataWidth) uart_bus ();
  uart_driver #(
      .DataWidth (DataWidth),
      .PulseWidth(PulseWidth)
  ) uart;

  logic [NumLED-1:0] led_o;
`ifndef POST_SYNTH_SIM
  top #(
      .BaudRate   (BaudRate),
      .RxFIFODepth(RxFIFODepth),
      .TxFIFODepth(TxFIFODepth)
  ) dut (
      .clk_i(clk_i),
      .rx_i (uart_bus.rx_i),
      .tx_o (uart_bus.tx_o),
      .led_o(led_o)
  );
`else
  top dut (
      .clk_i(clk_i),
      .rx_i (uart_bus.rx_i),
      .tx_o (uart_bus.tx_o),
      .led_o(led_o)
  );
`endif  // POST_SYNTH_SIM

  // Bind interface clock to internal PLL
  assign uart_bus.clk = dut.clock;

  logic [NumLED-1:0] expected_led;
  initial begin
    uart = new(uart_bus);

    // Wait until reset done and 1 PLL cycle after
    wait (dut.locked);
    @(posedge dut.clock);

    for (int unsigned i = 0; i < (2 ** DataWidth); i++) begin
      uart.write_and_expect(i, i);
      expected_led = ~NumLED'(i[NumLED-1:0]);

      // Only check lower `NumLED` bits
      if (expected_led !== led_o) begin
        $fatal(1, "LED output mismatch: expected 0b%b, received 0b%b", expected_led, led_o);
      end
    end

    $finish();
  end
endmodule : top_tb
