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
    parameter c_DATA_WIDTH = 8,
    parameter c_FIFO_DEPTH = 1024,
    parameter c_PACKET_SIZE = 512
) (
    input wire s_clk,
    input wire m_clk,
    input wire s_rst,
    input wire m_rst,

    input wire [c_DATA_WIDTH - 1:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,

    output wire [c_DATA_WIDTH - 1:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast,

    // Controls
    input wire i_xmii_phy_busy,
    output wire o_packet_ready
);

wire s_axis_tready_inst1;

axis_async_fifo #(
    .c_DATA_WIDTH(c_DATA_WIDTH),
    .c_FIFO_DEPTH(c_FIFO_DEPTH)
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

localparam c_MAX_PACKETS_BUFFERED = c_FIFO_DEPTH/c_PACKET_SIZE > 3 ? c_FIFO_DEPTH/c_PACKET_SIZE : 3;

wire s_axis_tready_inst2;

wire m_axis_tvalid_inst2;
wire m_axis_tlast_inst2;

assign s_axis_tready = s_axis_tready_inst1 && s_axis_tready_inst2;

assign o_packet_ready = m_axis_tvalid_inst2;

axis_async_fifo #(
    .c_DATA_WIDTH(1),
    // .c_FIFO_DEPTH(c_MAX_PACKETS_BUFFERED)
    .c_FIFO_DEPTH(c_FIFO_DEPTH)
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