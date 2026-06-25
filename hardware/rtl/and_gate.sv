`timescale 1ns / 1ps
`default_nettype none

module and_gate (
    input  logic a_i,
    input  logic b_i,
    output logic c_o
);
  assign c_o = a_i & b_i;
endmodule : and_gate
