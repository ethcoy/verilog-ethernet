module temp (
    input wire logic i_clk,

    input wire logic xmii_tx_clk,
    output wire logic [1:0] xmii_txd,
    output wire logic xmii_tx_en
);

logic [7:0] m_axis_tdata = '0;
logic m_axis_tvalid = 1'b0;
wire m_axis_tready;
logic m_axis_tlast = 1'b0;

logic [7:0] packet_reg [0:121];

initial begin
    $readmemh("packet_lut.mem", packet_reg);
end

localparam PACKET_LENGTH = 122;

logic [15:0] count_reg = '0;

initial begin
    m_axis_tdata = packet_reg[0];
    m_axis_tvalid = 1'b1;
end

always_ff @(posedge i_clk) begin
    if (m_axis_tvalid && m_axis_tready) begin
        m_axis_tdata <= packet_reg[count_reg + 1];
        count_reg <= count_reg + 1'b1;
        if (count_reg == PACKET_LENGTH - 2) begin
            m_axis_tlast <= 1'b1;
        end

        if (count_reg == PACKET_LENGTH - 1) begin
            m_axis_tdata <= packet_reg[0];
            m_axis_tlast <= 1'b0;
            count_reg <= '0;
        end
    end
end

wire [7:0] axis_mac_xmii_phy_async_fifo_inst_m_axis_tdata;
wire axis_mac_xmii_phy_async_fifo_inst_m_axis_tvalid;
wire axis_xmii_phy_tx_inst_s_axis_tready;
wire axis_mac_xmii_phy_async_fifo_inst_m_axis_tlast;

wire axis_xmii_phy_tx_inst_o_xmii_phy_tx_busy;
wire axis_mac_xmii_phy_async_fifo_inst_o_packet_ready;

axis_mac_xmii_phy_async_fifo #(
    .DATA_WIDTH(8),
    .FIFO_DEPTH(1526)
) 
axis_mac_xmii_phy_async_fifo_inst (
    .s_clk(i_clk),
    .m_clk(xmii_tx_clk),
    .s_rst(),
    .m_rst(),
    .s_axis_tdata(m_axis_tdata),
    .s_axis_tvalid(m_axis_tvalid),
    .s_axis_tready(m_axis_tready),
    .s_axis_tlast(m_axis_tlast),
    .m_axis_tdata(axis_mac_xmii_phy_async_fifo_inst_m_axis_tdata),
    .m_axis_tvalid(axis_mac_xmii_phy_async_fifo_inst_m_axis_tvalid),
    .m_axis_tready(axis_xmii_phy_tx_inst_s_axis_tready),
    .m_axis_tlast(axis_mac_xmii_phy_async_fifo_inst_m_axis_tlast),
    .i_xmii_phy_busy(axis_xmii_phy_tx_inst_o_xmii_phy_tx_busy),
    .o_packet_ready(axis_mac_xmii_phy_async_fifo_inst_o_packet_ready)
);


axis_xmii_phy_tx #(
    .DATA_WIDTH(8),
    .XMII_WIDTH(2)
) 
axis_xmii_phy_tx_inst (
    .i_rst(),

    .s_axis_tdata(axis_mac_xmii_phy_async_fifo_inst_m_axis_tdata),
    .s_axis_tvalid(axis_mac_xmii_phy_async_fifo_inst_m_axis_tvalid),
    .s_axis_tready(axis_xmii_phy_tx_inst_s_axis_tready),
    .s_axis_tlast(axis_mac_xmii_phy_async_fifo_inst_m_axis_tlast),

    .xmii_tx_clk(xmii_tx_clk),
    .xmii_txd(xmii_txd),
    .xmii_tx_en(xmii_tx_en),
    .xmii_tx_er(),

    .i_packet_ready(axis_mac_xmii_phy_async_fifo_inst_o_packet_ready),

    .o_xmii_phy_tx_busy(axis_xmii_phy_tx_inst_o_xmii_phy_tx_busy)
);

endmodule
