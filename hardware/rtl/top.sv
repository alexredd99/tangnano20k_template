`include "and_gate.sv"
`timescale 1ns / 1ps
`default_nettype none

module top (
    input  logic button0_i,  // pin 87
    input  logic button1_i,  // pin 88
    output logic led_o       // pin 20
);
  logic and_out;
  and_gate and_i (
      .a_i(button0_i),
      .b_i(button1_i),
      .c_o(and_out)
  );

  // Reverse polarity because LED pins are pulled up
  assign led_o = ~and_out;

endmodule : top
