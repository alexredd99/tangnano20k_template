`include "axis_fifo.sv"
`include "uart_rx.sv"
`include "uart_tx.sv"
`timescale 1ns / 1ps
`default_nettype none

module buffered_uart #(
    parameter  int unsigned ClkFreqHz    = 100_000_000,
    parameter  int unsigned BaudRate     = 115_200,
    parameter  int unsigned DataWidth    = 8,
    parameter  int unsigned RxFIFODepth  = 32,
    parameter  int unsigned TxFIFODepth  = 32,
    // Derived
    localparam int unsigned UARTPrescale = ClkFreqHz / (BaudRate * 8)
) (
    input  logic                 clk_i,
    input  logic                 rst_i,
    // AXIS input
    input  logic [DataWidth-1:0] s_axis_tdata,
    input  logic                 s_axis_tvalid,
    output logic                 s_axis_tready,
    // AXIS output
    output logic [DataWidth-1:0] m_axis_tdata,
    output logic                 m_axis_tvalid,
    input  logic                 m_axis_tready,
    // UART interface
    input  logic                 rx_i,
    output logic                 tx_o,
    // Status
    output logic                 rx_busy,
    output logic                 rx_overrun_error,
    output logic                 rx_frame_error,
    output logic                 tx_busy
);
  logic [DataWidth-1:0] uart_rx_tdata;
  logic uart_rx_tready;
  logic uart_rx_tvalid;
  uart_rx #(
      .DataWidth(DataWidth)
  ) i_uart_rx (
      .clk          (clk_i),
      .rst          (rst_i),
      .m_axis_tdata (uart_rx_tdata),
      .m_axis_tvalid(uart_rx_tvalid),
      .m_axis_tready(uart_rx_tready),
      .rx_i         (rx_i),
      .busy         (rx_busy),
      .overrun_error(rx_overrun_error),
      .frame_error  (rx_frame_error),
      .prescale     (16'(UARTPrescale))  // Fixed for now
  );

  axis_fifo #(
      .Depth     (RxFIFODepth),
      .DataWidth (DataWidth),
      .LastEnable(0),
      .IDEnable  (0),
      .DestEnable(0),
      .UserEnable(0)
  ) i_rx_fifo (
      .clk                (clk_i),
      .rst                (rst_i),
      .s_axis_tdata       (uart_rx_tdata),
      .s_axis_tkeep       ('0),              // unused
      .s_axis_tvalid      (uart_rx_tvalid),
      .s_axis_tready      (uart_rx_tready),
      .s_axis_tlast       ('0),              // unused
      .s_axis_tid         ('0),              // unused
      .s_axis_tdest       ('0),              // unused
      .s_axis_tuser       ('0),              // unused
      .m_axis_tdata       (m_axis_tdata),
      .m_axis_tkeep       (),                // unused
      .m_axis_tvalid      (m_axis_tvalid),
      .m_axis_tready      (m_axis_tready),
      .m_axis_tlast       (),                // unused
      .m_axis_tid         (),                // unused
      .m_axis_tdest       (),                // unused
      .m_axis_tuser       (),                // unused
      .pause_req          ('0),              // unused
      .pause_ack          (),                // unused
      .status_depth       (),                // unused
      .status_depth_commit(),                // unused
      .status_overflow    (),                // unused
      .status_bad_frame   (),                // unused
      .status_good_frame  ()                 // unused
  );

  logic [DataWidth-1:0] uart_tx_tdata;
  logic uart_tx_tvalid;
  logic uart_tx_tready;
  axis_fifo #(
      .Depth     (TxFIFODepth),
      .DataWidth (DataWidth),
      .LastEnable(0),
      .IDEnable  (0),
      .DestEnable(0),
      .UserEnable(0)
  ) i_tx_fifo (
      .clk                (clk_i),
      .rst                (rst_i),
      .s_axis_tdata       (s_axis_tdata),
      .s_axis_tkeep       ('0),              // unused
      .s_axis_tvalid      (s_axis_tvalid),
      .s_axis_tready      (s_axis_tready),
      .s_axis_tlast       ('0),              // unused
      .s_axis_tid         ('0),              // unused
      .s_axis_tdest       ('0),              // unused
      .s_axis_tuser       ('0),              // unused
      .m_axis_tdata       (uart_tx_tdata),
      .m_axis_tkeep       (),                // unused
      .m_axis_tvalid      (uart_tx_tvalid),
      .m_axis_tready      (uart_tx_tready),
      .m_axis_tlast       (),                // unused
      .m_axis_tid         (),                // unused
      .m_axis_tdest       (),                // unused
      .m_axis_tuser       (),                // unused
      .pause_req          ('0),              // unused
      .pause_ack          (),                // unused
      .status_depth       (),                // unused
      .status_depth_commit(),                // unused
      .status_overflow    (),                // unused
      .status_bad_frame   (),                // unused
      .status_good_frame  ()                 // unused
  );

  uart_tx #(
      .DataWidth(DataWidth)
  ) i_uart_tx (
      .clk          (clk_i),
      .rst          (rst_i),
      .s_axis_tdata (uart_tx_tdata),
      .s_axis_tvalid(uart_tx_tvalid),
      .s_axis_tready(uart_tx_tready),
      .tx_o         (tx_o),
      .busy         (tx_busy),
      .prescale     (16'(UARTPrescale))
  );

endmodule : buffered_uart
