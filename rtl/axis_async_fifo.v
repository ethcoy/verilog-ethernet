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

module axis_async_fifo #(
    parameter c_DATA_WIDTH = 16,
    parameter c_FIFO_DEPTH = 256
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
    output wire m_axis_tlast
);

localparam c_FIFO_WIDTH = c_DATA_WIDTH + 1'b1;

reg [c_FIFO_WIDTH - 1:0] r_fifo_data [0:c_FIFO_DEPTH - 1];

localparam c_ADDR_WIDTH = $clog2(c_FIFO_DEPTH) + 1;

reg [c_ADDR_WIDTH - 1:0] r_s_wr_addr = {c_ADDR_WIDTH{1'b0}};

reg [c_ADDR_WIDTH - 1:0] r_m_rd_addr = {c_ADDR_WIDTH{1'b0}};

reg [c_ADDR_WIDTH - 1:0] r_s_wr_addr_next = {c_ADDR_WIDTH{1'b0}};
reg [c_ADDR_WIDTH - 1:0] r_m_rd_addr_next = {c_ADDR_WIDTH{1'b0}};

wire [c_ADDR_WIDTH - 1:0] r_s_wr_gray;
reg [c_ADDR_WIDTH - 1:0] r_m_wr_gray = {c_ADDR_WIDTH{1'b0}};

reg [c_ADDR_WIDTH - 1:0] r_s_rd_gray = {c_ADDR_WIDTH{1'b0}};
wire [c_ADDR_WIDTH - 1:0] r_m_rd_gray;

assign r_s_wr_gray = (r_s_wr_addr >> 1'b1)^r_s_wr_addr;
assign r_m_rd_gray = (r_m_rd_addr >> 1'b1)^r_m_rd_addr;

reg [c_ADDR_WIDTH - 1:0] r_s_rd_gray_sync = {c_ADDR_WIDTH{1'b0}};
reg [c_ADDR_WIDTH - 1:0] r_m_wr_gray_sync = {c_ADDR_WIDTH{1'b0}};

reg r_read = 1'b0;
reg r_read_next = 1'b0;
reg r_write = 1'b0;

reg s_axis_tready_reg = 1'b0;

assign s_axis_tready = s_axis_tready_reg;

reg [c_DATA_WIDTH - 1:0] m_axis_tdata_reg = {c_DATA_WIDTH{1'b0}};
reg m_axis_tvalid_reg = 1'b0;
reg m_axis_tlast_reg = 1'b0;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

always @(*) begin
    s_axis_tready_reg = 1'b1;
    m_axis_tvalid_reg = 1'b0;
    r_s_wr_addr_next = r_s_wr_addr;
    r_m_rd_addr_next = r_m_rd_addr;
    r_write = 1'b0;
    r_read_next = 1'b1;

    if (r_s_wr_gray[c_ADDR_WIDTH - 1:c_ADDR_WIDTH - 2] == ~r_s_rd_gray[c_ADDR_WIDTH - 1:c_ADDR_WIDTH - 2] && r_s_wr_gray[c_ADDR_WIDTH - 3:0] == r_s_rd_gray[c_ADDR_WIDTH - 3:0]) begin
        s_axis_tready_reg = 1'b0;
    end

    if (s_axis_tvalid && s_axis_tready) begin
        r_write = 1'b1;
        r_s_wr_addr_next = r_s_wr_addr + 1'b1;
    end

    if (r_read) begin
        m_axis_tvalid_reg = 1'b1;
    end

    if (m_axis_tvalid && m_axis_tready) begin
        r_m_rd_addr_next = r_m_rd_addr + 1'b1;
    end

    if (r_m_rd_gray == r_m_wr_gray) begin
        r_read_next = 1'b0;
        r_m_rd_addr_next = r_m_rd_addr;
        m_axis_tvalid_reg = 1'b0;
    end
end

always @(posedge s_clk) begin
    r_s_rd_gray_sync <= r_m_rd_gray;
    r_s_rd_gray <= r_s_rd_gray_sync;
    r_s_wr_addr <= r_s_wr_addr_next;

    if (r_write) begin
        r_fifo_data[r_s_wr_addr[c_ADDR_WIDTH - 2:0]] <= {s_axis_tlast, s_axis_tdata};
    end

end

always @(posedge m_clk) begin
    r_m_wr_gray_sync <= r_s_wr_gray;
    r_m_wr_gray <= r_m_wr_gray_sync;
    r_m_rd_addr <= r_m_rd_addr_next;
    r_read <= r_read_next;

    if (r_read_next) begin
        m_axis_tdata_reg <= r_fifo_data[r_m_rd_addr_next[c_ADDR_WIDTH - 2:0]][c_DATA_WIDTH - 1:0];
        m_axis_tlast_reg <= r_fifo_data[r_m_rd_addr_next[c_ADDR_WIDTH - 2:0]][c_FIFO_WIDTH - 1];
    end

end

endmodule