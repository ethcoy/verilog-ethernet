/*

MIT License

Copyright (c) 2026 Ethan Coyle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

module axis_mac_xmii_phy_async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 1024
) (
    input wire logic s_clk,
    input wire logic m_clk,
    input wire logic s_rst,
    input wire logic m_rst,

    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    input wire logic m_axis_tready,
    output wire logic m_axis_tlast,

    // Controls
    input wire logic i_xmii_phy_busy,
    output wire logic o_packet_ready
);

wire s_axis_tready_inst1;

axis_async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) 
axis_async_fifo_inst1 (
    .s_clk(s_clk),
    .m_clk(m_clk),
    .s_rst(s_rst),
    .m_rst(m_rst),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready_inst1),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast)
);

// localparam MAX_PACKETS_BUFFERED = FIFO_DEPTH/PACKET_SIZE > 3 ? FIFO_DEPTH/PACKET_SIZE : 3;

wire s_axis_tready_inst2;

wire m_axis_tvalid_inst2;

assign s_axis_tready = s_axis_tready_inst1 && s_axis_tready_inst2;

assign o_packet_ready = m_axis_tvalid_inst2;

axis_async_fifo #(
    .DATA_WIDTH(1),
    // .FIFO_DEPTH(MAX_PACKETS_BUFFERED)
    .FIFO_DEPTH(FIFO_DEPTH)
) 
axis_async_fifo_inst2 (
    .s_clk(s_clk),
    .m_clk(m_clk),
    .s_rst(s_rst),
    .m_rst(m_rst),
    .s_axis_tdata(),
    .s_axis_tvalid(s_axis_tvalid && s_axis_tlast),
    .s_axis_tready(s_axis_tready_inst2),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tdata(),
    .m_axis_tvalid(m_axis_tvalid_inst2),
    .m_axis_tready(~i_xmii_phy_busy),
    .m_axis_tlast()
);

endmodule