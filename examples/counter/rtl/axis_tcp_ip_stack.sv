module axis_tcp_ip_stack #(
    parameter XMII_WIDTH = 2
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // xMII Tx interface
    input wire logic xmii_tx_clk,
    output wire logic [XMII_WIDTH - 1:0] xmii_txd,
    output wire logic xmii_tx_en,
    output wire logic xmii_tx_er
);

localparam DATA_LENGTH = 256;

wire [7:0] axis_counter_inst_m_axis_tdata;
wire axis_counter_inst_m_axis_tvalid;
wire axis_counter_inst_m_axis_tlast;

wire axis_udp_ipv4_stack_inst_s_axis_tready;

axis_counter #(
    .DATA_WIDTH(8)
) 
axis_counter_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .m_axis_tdata(axis_counter_inst_m_axis_tdata),
    .m_axis_tvalid(axis_counter_inst_m_axis_tvalid),
    .m_axis_tready(axis_udp_ipv4_stack_inst_s_axis_tready),
    .m_axis_tlast(axis_counter_inst_m_axis_tlast)
);

axis_udp_ipv4_stack_tx # (
    .DATA_WIDTH(8),
    .XMII_WIDTH(XMII_WIDTH),
    .FIFO_DEPTH(1536)
) 
axis_udp_ipv4_stack_tx_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .s_axis_udp_source_port(0),
    .s_axis_udp_destination_port(0),
    .s_axis_udp_length(8 + DATA_LENGTH),
    .s_axis_udp_header_tvalid(1'b1),
    .s_axis_udp_header_tready(),
    .s_axis_ipv4_version(4),
    .s_axis_ipv4_ihl(5),
    .s_axis_ipv4_dscp(0),
    .s_axis_ipv4_ecn(0),
    .s_axis_ipv4_length(20 + 8 + DATA_LENGTH),
    .s_axis_ipv4_id(0),
    .s_axis_ipv4_flags(2),
    .s_axis_ipv4_fragment_offset(0),
    .s_axis_ipv4_ttl(64),
    .s_axis_ipv4_protocol(17),
    .s_axis_ipv4_source_ip(32'hC0_00_02_06),
    .s_axis_ipv4_destination_ip(32'hC0_00_02_07),
    .s_axis_ipv4_header_tvalid(1'b1),
    .s_axis_ipv4_header_tready(),
    .s_axis_eth_destination_mac(48'hc4efbb5a967b),
    .s_axis_eth_source_mac(48'hc4efbb5a967c),
    .s_axis_eth_length(16'h0800),
    .s_axis_eth_header_tvalid(1'b1),
    .s_axis_eth_header_tready(),
    .s_axis_tdata(axis_counter_inst_m_axis_tdata),
    .s_axis_tvalid(axis_counter_inst_m_axis_tvalid),
    .s_axis_tready(axis_udp_ipv4_stack_inst_s_axis_tready),
    .s_axis_tlast(axis_counter_inst_m_axis_tlast),
    .xmii_tx_clk(xmii_tx_clk),
    .xmii_txd(xmii_txd),
    .xmii_tx_en(xmii_tx_en),
    .xmii_tx_er(xmii_tx_er)
);

endmodule
