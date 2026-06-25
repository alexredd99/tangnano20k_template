`ifndef POST_SYNTH_SIM
`include "../rtl/top.sv"
`endif  // POST_SYNTH_SIM

`timescale 1ns / 1ps
`default_nettype none

module top_tb;
  logic button0_i, button1_i;
  logic led_o;
  top dut (
      .button0_i(button0_i),
      .button1_i(button1_i),
      .led_o    (led_o)
  );

  logic expected;  // LED Value
  initial begin
    for (int unsigned vals = 0; vals <= 2'b11; vals++) begin
      {button0_i, button1_i} = vals[1:0];
      expected               = !(button0_i & button1_i);
      #1;

      if (led_o !== expected) begin
        $fatal(1, "ERROR: expected !(%b & %b) = %b, got %b", button0_i, button1_i, expected, led_o);
      end

      $display("[%0t] PASS: !(%b & %b) = %b", $time, button0_i, button1_i, led_o);
    end

    $finish();
  end
endmodule : top_tb
