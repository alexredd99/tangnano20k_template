`include "blinky.sv"
`include "common/axis_fifo.sv"
`include "common/buffered_uart.sv"
`timescale 1ns / 1ps
`default_nettype none

// Writes lower `NumLED` bits of received UART byte to LEDs
// Loopbacks received UART byte
module blinky_uart #(
    parameter int unsigned ClkFreqHz   = 100_000_000,
    parameter int unsigned NumLED      = 6,
    // UART Params
    parameter int unsigned BaudRate    = 115_200,
    parameter int unsigned RxFIFODepth = 32,
    parameter int unsigned TxFIFODepth = 32,
    parameter int unsigned DataWidth   = 8
) (
    input  logic              clk_i,
    input  logic              rst_i,
    input  logic              rx_i,
    output logic              tx_o,
    output logic [NumLED-1:0] led_o
);
  logic [DataWidth-1:0] uart_rx_tdata, uart_tx_tdata;
  logic uart_rx_tvalid, uart_rx_tready;
  logic uart_tx_tvalid, uart_tx_tready;
  buffered_uart #(
      .ClkFreqHz  (ClkFreqHz),
      .BaudRate   (BaudRate),
      .DataWidth  (DataWidth),
      .RxFIFODepth(RxFIFODepth),
      .TxFIFODepth(TxFIFODepth)
  ) i_uart (
      .clk_i           (clk_i),
      .rst_i           (rst_i),
      .s_axis_tdata    (uart_tx_tdata),
      .s_axis_tvalid   (uart_tx_tvalid),
      .s_axis_tready   (uart_tx_tready),
      .m_axis_tdata    (uart_rx_tdata),
      .m_axis_tvalid   (uart_rx_tvalid),
      .m_axis_tready   (uart_rx_tready),
      .rx_i            (rx_i),
      .tx_o            (tx_o),
      .rx_busy         (),                // unused
      .rx_overrun_error(),                // unused
      .rx_frame_error  (),                // unused
      .tx_busy         ()                 // unused
  );

  // Replace `blinky` with your AXI-Stream design

  blinky #(
      .DataWidth(DataWidth),
      .NumLED   (NumLED)
  ) i_blinky (
      .clk_i          (clk_i),
      .rst_i          (rst_i),
      .s_axis_tdata_i (uart_rx_tdata),
      .s_axis_tvalid_i(uart_rx_tvalid),
      .s_axis_tready_o(uart_rx_tready),
      .m_axis_tdata_o (uart_tx_tdata),
      .m_axis_tvalid_o(uart_tx_tvalid),
      .m_axis_tready_i(uart_tx_tready),
      .led_o          (led_o)
  );

endmodule : blinky_uart
