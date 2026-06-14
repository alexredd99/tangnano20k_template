`include "../rtl/blinky_uart.sv"
`include "uart_tb_pkg.sv"
`timescale 1ns / 1ps
`default_nettype none

module blinky_uart_tb #(
    parameter  int unsigned ClkFreqHz   = 100_000_000,
    parameter  int unsigned NumLED      = 6,
    // UART Params
    parameter  int unsigned BaudRate    = 2_000_000,
    parameter  int unsigned RxFIFODepth = 32,
    parameter  int unsigned TxFIFODepth = 32,
    parameter  int unsigned DataWidth   = 8,
    // Derived
    localparam realtime     ClkPeriodNs = 1e9 / ClkFreqHz,
    localparam int unsigned PulseWidth  = ClkFreqHz / BaudRate
);
  import uart_tb_pkg::*;

  logic clk_i = 0, rst_i = 1;
  initial forever #(ClkPeriodNs / 2) clk_i = ~clk_i;

  uart_if #(DataWidth) uart_bus ();
  assign uart_bus.clk = clk_i;

  uart_driver #(
      .DataWidth (DataWidth),
      .PulseWidth(PulseWidth)
  ) uart;

  logic [NumLED-1:0] led_o;
  blinky_uart #(
      .ClkFreqHz(ClkFreqHz),
      .BaudRate (BaudRate),
      .NumLED   (NumLED)
  ) dut (
      .clk_i(clk_i),
      .rst_i(rst_i),
      .rx_i (uart_bus.rx_i),
      .tx_o (uart_bus.tx_o),
      .led_o(led_o)
  );

  logic [NumLED-1:0] expected_led;
  initial begin
    uart = new(uart_bus);

    repeat (1) @(posedge clk_i);  // Reset for 1 cycle
    #2 rst_i = 0;
    repeat (1) @(posedge clk_i);  // Wait 1 cycle

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
endmodule : blinky_uart_tb
