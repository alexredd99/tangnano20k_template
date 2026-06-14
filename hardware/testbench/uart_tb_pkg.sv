`timescale 1ns / 1ps
`default_nettype none

interface uart_if #(
    parameter int unsigned DataWidth = 8
);
  // MUST ASSIGN `clk` when instantiating
  // This is a workaround for using internal PLL in DUT
  logic clk;
  logic rx_i, tx_o;
  initial rx_i = 1'b1;
endinterface : uart_if

// Helper for driving UART
package uart_tb_pkg;
  class uart_driver #(
      parameter int unsigned DataWidth  = 8,
      parameter int unsigned PulseWidth
  );
    virtual uart_if #(DataWidth) v_if;
    function new(virtual uart_if #(DataWidth) v_if);
      this.v_if = v_if;
    endfunction

    task automatic write_byte(input logic [DataWidth-1:0] data);
      v_if.rx_i = 1'b1;
      repeat (PulseWidth) @(posedge v_if.clk);
      v_if.rx_i = 1'b0;  // start bit
      repeat (PulseWidth) @(posedge v_if.clk);

      for (int unsigned i = 0; i < DataWidth; i++) begin
        v_if.rx_i = data[i];
        repeat (PulseWidth) @(posedge v_if.clk);
      end

      v_if.rx_i = 1'b1;  // stop bit
      repeat (PulseWidth) @(posedge v_if.clk);
      v_if.rx_i = 1'b1;  // idle
      repeat (PulseWidth) @(posedge v_if.clk);
    endtask

    task automatic read_byte(output logic [DataWidth-1:0] data);
      int unsigned timeout = 100 * PulseWidth;
      data = '0;

      // Wait for tx_o start bit.
      while (v_if.tx_o !== 1'b0 && timeout > 0) begin
        @(posedge v_if.clk);
        timeout--;
      end

      if (timeout == 0) begin
        $fatal(1, "Timed out waiting for TX start bit");
      end

      // Move to center of start bit.
      repeat (PulseWidth / 2) @(posedge v_if.clk);
      if (v_if.tx_o !== 1'b0) begin
        $fatal(1, "False start bit: tx_o returned high");
      end

      // Sample data bits in the middle of each bit period.
      for (int unsigned i = 0; i < DataWidth; i++) begin
        repeat (PulseWidth) @(posedge v_if.clk);
        data[i] = v_if.tx_o;
      end

      // Sample stop bit.
      repeat (PulseWidth) @(posedge v_if.clk);
      if (v_if.tx_o !== 1'b1) begin
        $fatal(1, "Bad stop bit: tx_o = %b", v_if.tx_o);
      end
    endtask

    task automatic write_and_expect(input logic [DataWidth-1:0] sent,
                                    input logic [DataWidth-1:0] expected);
      logic [DataWidth-1:0] received;
      fork
        write_byte(sent);
        read_byte(received);
      join

      if (received !== expected) begin
        $fatal(1, "sent 0x%h, received 0x%h, expected: %h", sent, received, expected);
      end

      $display("[%0t] PASS: sent 0x%h, received 0x%h", $time, sent, received);
    endtask
  endclass : uart_driver

endpackage : uart_tb_pkg
