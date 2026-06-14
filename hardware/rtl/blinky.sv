`timescale 1ns / 1ps
`default_nettype none

module blinky #(
    parameter int unsigned DataWidth = 8,
    parameter int unsigned NumLED    = 6
) (
    input  logic                 clk_i,
    input  logic                 rst_i,
    // AXIS input (UART Rx)
    input  logic [DataWidth-1:0] s_axis_tdata_i,
    input  logic                 s_axis_tvalid_i,
    output logic                 s_axis_tready_o,
    // AXIS output
    output logic [DataWidth-1:0] m_axis_tdata_o,
    output logic                 m_axis_tvalid_o,
    input  logic                 m_axis_tready_i,
    // LED control
    output logic [   NumLED-1:0] led_o
);
  typedef enum logic {
    STATE_RECEIVE,
    STATE_SEND
  } state_t;
  state_t state;

  logic [DataWidth-1:0] received_data;
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state           <= STATE_RECEIVE;
      received_data   <= '0;
      s_axis_tready_o <= 0;
      m_axis_tvalid_o <= 0;
    end else begin
      m_axis_tvalid_o <= 0;

      unique case (state)
        STATE_RECEIVE: begin
          s_axis_tready_o <= 1;
          if (s_axis_tvalid_i) begin
            state           <= STATE_SEND;
            s_axis_tready_o <= 0;
            received_data   <= s_axis_tdata_i;
          end
        end
        STATE_SEND: begin
          if (m_axis_tready_i) begin
            state           <= STATE_RECEIVE;
            m_axis_tdata_o  <= received_data;
            m_axis_tvalid_o <= 1;
          end
        end
      endcase
    end
  end

  // Reverse polarity because LED pins are pulled up
  assign led_o = NumLED'(~received_data);

endmodule : blinky
