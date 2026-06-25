`ifndef POST_SYNTH_SIM
`include "../rtl/and_gate.sv"
`endif  // POST_SYNTH_SIM

`timescale 1ns / 1ps
`default_nettype none

module and_gate_tb;
  logic a_i, b_i;
  logic c_o;
  and_gate dut (
      .a_i(a_i),
      .b_i(b_i),
      .c_o(c_o)
  );

  logic expected;
  initial begin
    for (int unsigned vals = 0; vals <= 2'b11; vals++) begin
      {a_i, b_i} = vals[1:0];
      expected   = a_i & b_i;
      #1;

      if (c_o !== expected) begin
        $fatal(1, "ERROR: expected %b & %b = %b, got %b", a_i, b_i, expected, c_o);
      end

      $display("[%0t] PASS: %b & %b = %b", $time, a_i, b_i, c_o);
    end

    $finish();
  end
endmodule : and_gate_tb
