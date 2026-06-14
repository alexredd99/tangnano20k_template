`ifndef INC_FIFO
`define INC_FIFO
// Copyright (c) 2013-2023 Alex Forencich
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
`resetall
`timescale 1ns / 1ps
`default_nettype none

// AXI4-Stream FIFO
module axis_fifo #(
    // FIFO depth in words
    // KeepWidth words per cycle if KeepEnable set
    // Rounded up to nearest power of 2 cycles
    parameter int unsigned Depth             = 4096,
    // Width of AXI stream interfaces in bits
    parameter int unsigned DataWidth         = 8,
    // Propagate tkeep signal
    // If disabled, tkeep assumed to be 1'b1
    parameter int unsigned KeepEnable        = (DataWidth > 8),
    // tkeep signal width (words per cycle)
    parameter int unsigned KeepWidth         = ((DataWidth + 7) / 8),
    // Propagate tlast signal
    parameter int unsigned LastEnable        = 1,
    // Propagate tid signal
    parameter int unsigned IDEnable          = 0,
    // tid signal width
    parameter int unsigned IDWidth           = 8,
    // Propagate tdest signal
    parameter int unsigned DestEnable        = 0,
    // tdest signal width
    parameter int unsigned DestWidth         = 8,
    // Propagate tuser signal
    parameter int unsigned UserEnable        = 1,
    // tuser signal width
    parameter int unsigned UserWidth         = 1,
    // number of RAM pipeline registers
    parameter int unsigned RamPipeline       = 1,
    // use output FIFO
    // When set, the RAM read enable and pipeline clock enables are removed
    parameter int unsigned OutputFIFOEnable  = 0,
    // Frame FIFO mode - operate on frames instead of cycles
    // When set, m_axis_tvalid will not be deasserted within a frame
    // Requires LastEnable set
    parameter int unsigned FrameFIFO         = 0,
    // tuser value for bad frame marker
    parameter int unsigned UserBadFrameValue = 1'b1,
    // tuser mask for bad frame marker
    parameter int unsigned UserBadFrameMask  = 1'b1,
    // Drop frames larger than FIFO
    // Requires FrameFIFO set
    parameter int unsigned DropOversizeFrame = FrameFIFO,
    // Drop frames marked bad
    // Requires FrameFIFO and DropOversizeFrame set
    parameter int unsigned DropBadFrame      = 0,
    // Drop incoming frames when full
    // When set, s_axis_tready is always asserted
    // Requires FrameFIFO and DropOversizeFrame set
    parameter int unsigned DropWhenFull      = 0,
    // Mark incoming frames as bad frames when full
    // When set, s_axis_tready is always asserted
    // Requires FrameFIFO to be clear
    parameter int unsigned MarkWhenFull      = 0,
    // Enable pause request input
    parameter int unsigned PauseEnable       = 0,
    // Pause between frames
    parameter int unsigned FramePause        = FrameFIFO
) (
    input  wire                   clk,
    input  wire                   rst,
    // AXI input
    input  wire [  DataWidth-1:0] s_axis_tdata,
    input  wire [  KeepWidth-1:0] s_axis_tkeep,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    input  wire [    IDWidth-1:0] s_axis_tid,
    input  wire [  DestWidth-1:0] s_axis_tdest,
    input  wire [  UserWidth-1:0] s_axis_tuser,
    // AXI output
    output wire [  DataWidth-1:0] m_axis_tdata,
    output wire [  KeepWidth-1:0] m_axis_tkeep,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    output wire [    IDWidth-1:0] m_axis_tid,
    output wire [  DestWidth-1:0] m_axis_tdest,
    output wire [  UserWidth-1:0] m_axis_tuser,
    // Pause
    input  wire                   pause_req,
    output wire                   pause_ack,
    // Status
    output wire [$clog2(Depth):0] status_depth,
    output wire [$clog2(Depth):0] status_depth_commit,
    output wire                   status_overflow,
    output wire                   status_bad_frame,
    output wire                   status_good_frame
);

  parameter int unsigned AddrWidth = (KeepEnable && KeepWidth > 1) ? $clog2(
      Depth / KeepWidth
  ) : $clog2(
      Depth
  );
  parameter int unsigned ClKeepWidth = $clog2(KeepWidth);

  parameter int unsigned OutputFIFOAddrWidth = RamPipeline < 2 ? 3 : $clog2(RamPipeline * 2 + 7);

  // check configuration
  initial begin
    if (FrameFIFO && !LastEnable) begin
      $error("Error: FrameFIFO set requires LastEnable set (instance %m)");
      $finish;
    end

    if (DropOversizeFrame && !FrameFIFO) begin
      $error("Error: DropOversizeFrame set requires FrameFIFO set (instance %m)");
      $finish;
    end

    if (DropBadFrame && !(FrameFIFO && DropOversizeFrame)) begin
      $error("Error: DropBadFrame set requires FrameFIFO and DropOversizeFrame set (instance %m)");
      $finish;
    end

    if (DropWhenFull && !(FrameFIFO && DropOversizeFrame)) begin
      $error("Error: DropWhenFull set requires FrameFIFO and DropOversizeFrame set (instance %m)");
      $finish;
    end

    if ((DropBadFrame || MarkWhenFull) && (UserBadFrameMask & {UserWidth{1'b1}}) == 0) begin
      $error("Error: Invalid UserBadFrameMask value (instance %m)");
      $finish;
    end

    if (MarkWhenFull && FrameFIFO) begin
      $error("Error: MarkWhenFull is not compatible with FrameFIFO (instance %m)");
      $finish;
    end

    if (MarkWhenFull && !LastEnable) begin
      $error("Error: MarkWhenFull set requires LastEnable set (instance %m)");
      $finish;
    end
  end

  localparam int unsigned KeepOffset = DataWidth;
  localparam int unsigned LastOffset = KeepOffset + (KeepEnable ? KeepWidth : 0);
  localparam int unsigned IDOffset = LastOffset + (LastEnable ? 1 : 0);
  localparam int unsigned DestOffset = IDOffset + (IDEnable ? IDWidth : 0);
  localparam int unsigned UserOffset = DestOffset + (DestEnable ? DestWidth : 0);
  localparam int unsigned Width = UserOffset + (UserEnable ? UserWidth : 0);

  reg [AddrWidth:0] wr_ptr_reg = {AddrWidth + 1{1'b0}};
  reg [AddrWidth:0] wr_ptr_commit_reg = {AddrWidth + 1{1'b0}};
  reg [AddrWidth:0] rd_ptr_reg = {AddrWidth + 1{1'b0}};

  (* ramstyle = "no_rw_check" *)
  reg [Width-1:0] mem[(2**AddrWidth)-1:0];
  reg mem_read_data_valid_reg = 1'b0;

  (* shreg_extract = "no" *)
  reg [Width-1:0] m_axis_pipe_reg[RamPipeline+1-1:0];
  reg [RamPipeline+1-1:0] m_axis_tvalid_pipe_reg = 0;

  // full when first MSB different but rest same
  wire full = wr_ptr_reg == (rd_ptr_reg ^ {1'b1, {AddrWidth{1'b0}}});
  // empty when pointers match exactly
  wire empty = wr_ptr_commit_reg == rd_ptr_reg;
  // overflow within packet
  wire full_wr = wr_ptr_reg == (wr_ptr_commit_reg ^ {1'b1, {AddrWidth{1'b0}}});

  reg s_frame_reg = 1'b0;

  reg drop_frame_reg = 1'b0;
  reg mark_frame_reg = 1'b0;
  reg send_frame_reg = 1'b0;
  reg [AddrWidth:0] depth_reg = 0;
  reg [AddrWidth:0] depth_commit_reg = 0;
  reg overflow_reg = 1'b0;
  reg bad_frame_reg = 1'b0;
  reg good_frame_reg = 1'b0;

  assign s_axis_tready = FrameFIFO ? (!full || (full_wr && DropOversizeFrame) || DropWhenFull) : (!full || MarkWhenFull);

  wire [Width-1:0] s_axis;

  generate
    assign s_axis[DataWidth-1:0] = s_axis_tdata;
    if (KeepEnable) assign s_axis[KeepOffset+:KeepWidth] = s_axis_tkeep;
    if (LastEnable) assign s_axis[LastOffset] = s_axis_tlast | mark_frame_reg;
    if (IDEnable) assign s_axis[IDOffset+:IDWidth] = s_axis_tid;
    if (DestEnable) assign s_axis[DestOffset+:DestWidth] = s_axis_tdest;
    if (UserEnable)
      assign s_axis[UserOffset+:UserWidth] = mark_frame_reg ? UserBadFrameValue : s_axis_tuser;
  endgenerate

  wire [Width-1:0] m_axis = m_axis_pipe_reg[RamPipeline+1-1];

  wire m_axis_tready_pipe;
  wire m_axis_tvalid_pipe = m_axis_tvalid_pipe_reg[RamPipeline+1-1];

  wire [DataWidth-1:0] m_axis_tdata_pipe = m_axis[DataWidth-1:0];
  wire [KeepWidth-1:0]  m_axis_tkeep_pipe  = KeepEnable ? m_axis[KeepOffset +: KeepWidth] : {KeepWidth{1'b1}};
  wire m_axis_tlast_pipe = LastEnable ? m_axis[LastOffset] : 1'b1;
  wire [IDWidth-1:0] m_axis_tid_pipe = IDEnable ? m_axis[IDOffset+:IDWidth] : {IDWidth{1'b0}};
  wire [DestWidth-1:0]  m_axis_tdest_pipe  = DestEnable ? m_axis[DestOffset +: DestWidth] : {DestWidth{1'b0}};
  wire [UserWidth-1:0]  m_axis_tuser_pipe  = UserEnable ? m_axis[UserOffset +: UserWidth] : {UserWidth{1'b0}};

  wire m_axis_tready_out;
  wire m_axis_tvalid_out;

  wire [DataWidth-1:0] m_axis_tdata_out;
  wire [KeepWidth-1:0] m_axis_tkeep_out;
  wire m_axis_tlast_out;
  wire [IDWidth-1:0] m_axis_tid_out;
  wire [DestWidth-1:0] m_axis_tdest_out;
  wire [UserWidth-1:0] m_axis_tuser_out;

  wire pipe_ready;

  assign status_depth = (KeepEnable && KeepWidth > 1) ? {depth_reg, {ClKeepWidth{1'b0}}} : depth_reg;
  assign status_depth_commit = (KeepEnable && KeepWidth > 1) ? {depth_commit_reg, {ClKeepWidth{1'b0}}} : depth_commit_reg;
  assign status_overflow = overflow_reg;
  assign status_bad_frame = bad_frame_reg;
  assign status_good_frame = good_frame_reg;

  // Write logic
  always @(posedge clk) begin
    overflow_reg   <= 1'b0;
    bad_frame_reg  <= 1'b0;
    good_frame_reg <= 1'b0;

    if (s_axis_tready && s_axis_tvalid && LastEnable) begin
      // track input frame status
      s_frame_reg <= !s_axis_tlast;
    end

    if (FrameFIFO) begin
      // frame FIFO mode
      if (s_axis_tready && s_axis_tvalid) begin
        // transfer in
        if ((full && DropWhenFull) || (full_wr && DropOversizeFrame) || drop_frame_reg) begin
          // full, packet overflow, or currently dropping frame
          // drop frame
          drop_frame_reg <= 1'b1;
          if (s_axis_tlast) begin
            // end of frame, reset write pointer
            wr_ptr_reg     <= wr_ptr_commit_reg;
            drop_frame_reg <= 1'b0;
            overflow_reg   <= 1'b1;
          end
        end else begin
          // store it
          mem[wr_ptr_reg[AddrWidth-1:0]] <= s_axis;
          wr_ptr_reg                     <= wr_ptr_reg + 1;
          if (s_axis_tlast || (!DropOversizeFrame && (full_wr || send_frame_reg))) begin
            // end of frame or send frame
            send_frame_reg <= !s_axis_tlast;
            if (s_axis_tlast && DropBadFrame && UserBadFrameMask & ~(s_axis_tuser ^ UserBadFrameValue)) begin
              // bad packet, reset write pointer
              wr_ptr_reg    <= wr_ptr_commit_reg;
              bad_frame_reg <= 1'b1;
            end else begin
              // good packet or packet overflow, update write pointer
              wr_ptr_commit_reg <= wr_ptr_reg + 1;
              good_frame_reg    <= s_axis_tlast;
            end
          end
        end
      end else if (s_axis_tvalid && full_wr && !DropOversizeFrame) begin
        // data valid with packet overflow
        // update write pointer
        send_frame_reg    <= 1'b1;
        wr_ptr_commit_reg <= wr_ptr_reg;
      end
    end else begin
      // normal FIFO mode
      if (s_axis_tready && s_axis_tvalid) begin
        if (drop_frame_reg && MarkWhenFull) begin
          // currently dropping frame
          if (s_axis_tlast) begin
            // end of frame
            if (!full && mark_frame_reg) begin
              // terminate marked frame
              mark_frame_reg                 <= 1'b0;
              mem[wr_ptr_reg[AddrWidth-1:0]] <= s_axis;
              wr_ptr_reg                     <= wr_ptr_reg + 1;
              wr_ptr_commit_reg              <= wr_ptr_reg + 1;
            end
            // end of frame, clear drop flag
            drop_frame_reg <= 1'b0;
            overflow_reg   <= 1'b1;
          end
        end else if ((full || mark_frame_reg) && MarkWhenFull) begin
          // full or marking frame
          // drop frame; mark if this isn't the first cycle
          drop_frame_reg <= 1'b1;
          mark_frame_reg <= mark_frame_reg || s_frame_reg;
          if (s_axis_tlast) begin
            drop_frame_reg <= 1'b0;
            overflow_reg   <= 1'b1;
          end
        end else begin
          // transfer in
          mem[wr_ptr_reg[AddrWidth-1:0]] <= s_axis;
          wr_ptr_reg                     <= wr_ptr_reg + 1;
          wr_ptr_commit_reg              <= wr_ptr_reg + 1;
        end
      end else if ((!full && !drop_frame_reg && mark_frame_reg) && MarkWhenFull) begin
        // terminate marked frame
        mark_frame_reg                 <= 1'b0;
        mem[wr_ptr_reg[AddrWidth-1:0]] <= s_axis;
        wr_ptr_reg                     <= wr_ptr_reg + 1;
        wr_ptr_commit_reg              <= wr_ptr_reg + 1;
      end
    end

    if (rst) begin
      wr_ptr_reg        <= {AddrWidth + 1{1'b0}};
      wr_ptr_commit_reg <= {AddrWidth + 1{1'b0}};

      s_frame_reg       <= 1'b0;

      drop_frame_reg    <= 1'b0;
      mark_frame_reg    <= 1'b0;
      send_frame_reg    <= 1'b0;
      overflow_reg      <= 1'b0;
      bad_frame_reg     <= 1'b0;
      good_frame_reg    <= 1'b0;
    end
  end

  // Status
  always @(posedge clk) begin
    depth_reg        <= wr_ptr_reg - rd_ptr_reg;
    depth_commit_reg <= wr_ptr_commit_reg - rd_ptr_reg;
  end

  // Read logic
  integer j;

  always @(posedge clk) begin
    if (m_axis_tready_pipe) begin
      // output ready; invalidate stage
      m_axis_tvalid_pipe_reg[RamPipeline+1-1] <= 1'b0;
    end

    for (j = RamPipeline + 1 - 1; j > 0; j = j - 1) begin
      if (m_axis_tready_pipe || ((~m_axis_tvalid_pipe_reg) >> j)) begin
        // output ready or bubble in pipeline; transfer down pipeline
        m_axis_tvalid_pipe_reg[j]   <= m_axis_tvalid_pipe_reg[j-1];
        m_axis_pipe_reg[j]          <= m_axis_pipe_reg[j-1];
        m_axis_tvalid_pipe_reg[j-1] <= 1'b0;
      end
    end

    if (m_axis_tready_pipe || ~m_axis_tvalid_pipe_reg) begin
      // output ready or bubble in pipeline; read new data from FIFO
      m_axis_tvalid_pipe_reg[0] <= 1'b0;
      m_axis_pipe_reg[0]        <= mem[rd_ptr_reg[AddrWidth-1:0]];
      if (!empty && pipe_ready) begin
        // not empty, increment pointer
        m_axis_tvalid_pipe_reg[0] <= 1'b1;
        rd_ptr_reg                <= rd_ptr_reg + 1;
      end
    end

    if (rst) begin
      rd_ptr_reg             <= {AddrWidth + 1{1'b0}};
      m_axis_tvalid_pipe_reg <= 0;
    end
  end

  generate

    if (!OutputFIFOEnable) begin

      assign pipe_ready         = 1'b1;

      assign m_axis_tready_pipe = m_axis_tready_out;
      assign m_axis_tvalid_out  = m_axis_tvalid_pipe;

      assign m_axis_tdata_out   = m_axis_tdata_pipe;
      assign m_axis_tkeep_out   = m_axis_tkeep_pipe;
      assign m_axis_tlast_out   = m_axis_tlast_pipe;
      assign m_axis_tid_out     = m_axis_tid_pipe;
      assign m_axis_tdest_out   = m_axis_tdest_pipe;
      assign m_axis_tuser_out   = m_axis_tuser_pipe;

    end else begin : output_fifo

      // output datapath logic
      reg [DataWidth-1:0] m_axis_tdata_reg = {DataWidth{1'b0}};
      reg [KeepWidth-1:0] m_axis_tkeep_reg = {KeepWidth{1'b0}};
      reg m_axis_tvalid_reg = 1'b0;
      reg m_axis_tlast_reg = 1'b0;
      reg [IDWidth-1:0] m_axis_tid_reg = {IDWidth{1'b0}};
      reg [DestWidth-1:0] m_axis_tdest_reg = {DestWidth{1'b0}};
      reg [UserWidth-1:0] m_axis_tuser_reg = {UserWidth{1'b0}};

      reg [OutputFIFOAddrWidth+1-1:0] out_fifo_wr_ptr_reg = 0;
      reg [OutputFIFOAddrWidth+1-1:0] out_fifo_rd_ptr_reg = 0;
      reg out_fifo_half_full_reg = 1'b0;

      wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OutputFIFOAddrWidth{1'b0}}});
      wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

      (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
      reg [DataWidth-1:0] out_fifo_tdata[2**OutputFIFOAddrWidth-1:0];
      (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
      reg [KeepWidth-1:0] out_fifo_tkeep[2**OutputFIFOAddrWidth-1:0];
      (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
      reg out_fifo_tlast[2**OutputFIFOAddrWidth-1:0];
      (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
      reg [IDWidth-1:0] out_fifo_tid[2**OutputFIFOAddrWidth-1:0];
      (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
      reg [DestWidth-1:0] out_fifo_tdest[2**OutputFIFOAddrWidth-1:0];
      (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
      reg [UserWidth-1:0] out_fifo_tuser[2**OutputFIFOAddrWidth-1:0];

      assign pipe_ready         = !out_fifo_half_full_reg;

      assign m_axis_tready_pipe = 1'b1;

      assign m_axis_tdata_out   = m_axis_tdata_reg;
      assign m_axis_tkeep_out   = KeepEnable ? m_axis_tkeep_reg : {KeepWidth{1'b1}};
      assign m_axis_tvalid_out  = m_axis_tvalid_reg;
      assign m_axis_tlast_out   = LastEnable ? m_axis_tlast_reg : 1'b1;
      assign m_axis_tid_out     = IDEnable ? m_axis_tid_reg : {IDWidth{1'b0}};
      assign m_axis_tdest_out   = DestEnable ? m_axis_tdest_reg : {DestWidth{1'b0}};
      assign m_axis_tuser_out   = UserEnable ? m_axis_tuser_reg : {UserWidth{1'b0}};

      always @(posedge clk) begin
        m_axis_tvalid_reg <= m_axis_tvalid_reg && !m_axis_tready_out;

        out_fifo_half_full_reg <= $unsigned(
            out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg
        ) >= 2 ** (OutputFIFOAddrWidth - 1);

        if (!out_fifo_full && m_axis_tvalid_pipe) begin
          out_fifo_tdata[out_fifo_wr_ptr_reg[OutputFIFOAddrWidth-1:0]] <= m_axis_tdata_pipe;
          out_fifo_tkeep[out_fifo_wr_ptr_reg[OutputFIFOAddrWidth-1:0]] <= m_axis_tkeep_pipe;
          out_fifo_tlast[out_fifo_wr_ptr_reg[OutputFIFOAddrWidth-1:0]] <= m_axis_tlast_pipe;
          out_fifo_tid[out_fifo_wr_ptr_reg[OutputFIFOAddrWidth-1:0]]   <= m_axis_tid_pipe;
          out_fifo_tdest[out_fifo_wr_ptr_reg[OutputFIFOAddrWidth-1:0]] <= m_axis_tdest_pipe;
          out_fifo_tuser[out_fifo_wr_ptr_reg[OutputFIFOAddrWidth-1:0]] <= m_axis_tuser_pipe;
          out_fifo_wr_ptr_reg                                          <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!m_axis_tvalid_reg || m_axis_tready_out)) begin
          m_axis_tdata_reg    <= out_fifo_tdata[out_fifo_rd_ptr_reg[OutputFIFOAddrWidth-1:0]];
          m_axis_tkeep_reg    <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OutputFIFOAddrWidth-1:0]];
          m_axis_tvalid_reg   <= 1'b1;
          m_axis_tlast_reg    <= out_fifo_tlast[out_fifo_rd_ptr_reg[OutputFIFOAddrWidth-1:0]];
          m_axis_tid_reg      <= out_fifo_tid[out_fifo_rd_ptr_reg[OutputFIFOAddrWidth-1:0]];
          m_axis_tdest_reg    <= out_fifo_tdest[out_fifo_rd_ptr_reg[OutputFIFOAddrWidth-1:0]];
          m_axis_tuser_reg    <= out_fifo_tuser[out_fifo_rd_ptr_reg[OutputFIFOAddrWidth-1:0]];
          out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (rst) begin
          out_fifo_wr_ptr_reg <= 0;
          out_fifo_rd_ptr_reg <= 0;
          m_axis_tvalid_reg   <= 1'b0;
        end
      end

    end

    if (PauseEnable) begin : pause

      // Pause logic
      reg pause_reg = 1'b0;
      reg pause_frame_reg = 1'b0;

      assign m_axis_tready_out = m_axis_tready && !pause_reg;
      assign m_axis_tvalid     = m_axis_tvalid_out && !pause_reg;

      assign m_axis_tdata      = m_axis_tdata_out;
      assign m_axis_tkeep      = m_axis_tkeep_out;
      assign m_axis_tlast      = m_axis_tlast_out;
      assign m_axis_tid        = m_axis_tid_out;
      assign m_axis_tdest      = m_axis_tdest_out;
      assign m_axis_tuser      = m_axis_tuser_out;

      assign pause_ack         = pause_reg;

      always @(posedge clk) begin
        if (FramePause) begin
          if (pause_reg) begin
            // paused; update pause status
            pause_reg <= pause_req;
          end else if (m_axis_tvalid_out) begin
            // frame transfer; set frame bit
            pause_frame_reg <= 1'b1;
            if (m_axis_tready && m_axis_tlast) begin
              // end of frame; clear frame bit and update pause status
              pause_frame_reg <= 1'b0;
              pause_reg       <= pause_req;
            end
          end else if (!pause_frame_reg) begin
            // idle; update pause status
            pause_reg <= pause_req;
          end
        end else begin
          pause_reg <= pause_req;
        end

        if (rst) begin
          pause_frame_reg <= 1'b0;
          pause_reg       <= 1'b0;
        end
      end

    end else begin

      assign m_axis_tready_out = m_axis_tready;
      assign m_axis_tvalid     = m_axis_tvalid_out;

      assign m_axis_tdata      = m_axis_tdata_out;
      assign m_axis_tkeep      = m_axis_tkeep_out;
      assign m_axis_tlast      = m_axis_tlast_out;
      assign m_axis_tid        = m_axis_tid_out;
      assign m_axis_tdest      = m_axis_tdest_out;
      assign m_axis_tuser      = m_axis_tuser_out;

      assign pause_ack         = 1'b0;

    end

  endgenerate

endmodule

`resetall
`endif  // INC_FIFO
