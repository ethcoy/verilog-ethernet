module axis_udp_ipv4_stack_tx # (
    parameter DATA_WIDTH = 8,
    parameter XMII_WIDTH = 4,
    parameter FIFO_DEPTH = 1500
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // UDP AXI-Stream header sink interface
    input wire logic [15:0] s_axis_udp_source_port,
    input wire logic [15:0] s_axis_udp_destination_port,
    input wire logic [15:0] s_axis_udp_length,
    input wire logic s_axis_udp_header_tvalid,
    output wire logic s_axis_udp_header_tready,

    // IPv4 AXI-Stream sink header interface
    input wire logic [3:0] s_axis_ipv4_version,
    input wire logic [3:0] s_axis_ipv4_ihl,
    input wire logic [5:0] s_axis_ipv4_dscp,
    input wire logic [1:0] s_axis_ipv4_ecn,
    input wire logic [15:0] s_axis_ipv4_length,
    input wire logic [15:0] s_axis_ipv4_id,
    input wire logic [2:0] s_axis_ipv4_flags,
    input wire logic [12:0] s_axis_ipv4_fragment_offset,
    input wire logic [7:0] s_axis_ipv4_ttl,
    input wire logic [7:0] s_axis_ipv4_protocol,
    input wire logic [31:0] s_axis_ipv4_source_ip,
    input wire logic [31:0] s_axis_ipv4_destination_ip,
    input wire logic s_axis_ipv4_header_tvalid,
    output wire logic s_axis_ipv4_header_tready,

    // Ethernet AXI-Stream header sink interface
    input wire logic [47:0] s_axis_eth_destination_mac,
    input wire logic [47:0] s_axis_eth_source_mac,
    input wire logic [15:0] s_axis_eth_length,
    input wire logic s_axis_eth_header_tvalid,
    output wire logic s_axis_eth_header_tready,

    // Stack AXI-Stream data sink interface
    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    // xMII Tx interface
    input wire logic xmii_tx_clk,
    output wire logic [XMII_WIDTH - 1:0] xmii_txd,
    output wire logic xmii_tx_en,
    output wire logic xmii_tx_er
);

wire [DATA_WIDTH - 1:0] axis_udp_tx_inst_m_axis_tdata;
wire axis_udp_tx_inst_m_axis_tvalid;
wire axis_udp_tx_inst_m_axis_tlast;

wire axis_ipv4_tx_inst_s_axis_tready;

axis_udp_tx #(
    .DATA_WIDTH(DATA_WIDTH)
) 
axis_udp_tx_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .s_axis_udp_source_port(s_axis_udp_source_port),
    .s_axis_udp_destination_port(s_axis_udp_destination_port),
    .s_axis_udp_length(s_axis_udp_length),
    .s_axis_udp_header_tvalid(s_axis_udp_header_tvalid),
    .s_axis_udp_header_tready(s_axis_udp_header_tready),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tdata(axis_udp_tx_inst_m_axis_tdata),
    .m_axis_tvalid(axis_udp_tx_inst_m_axis_tvalid),
    .m_axis_tready(axis_ipv4_tx_inst_s_axis_tready),
    .m_axis_tlast(axis_udp_tx_inst_m_axis_tlast)
);

wire [DATA_WIDTH - 1:0] axis_ipv4_tx_inst_m_axis_tdata;
wire axis_ipv4_tx_inst_m_axis_tvalid;
wire axis_ipv4_tx_inst_m_axis_tlast;

wire axis_mac_tx_inst_s_axis_tready;

axis_ipv4_tx #(
    .DATA_WIDTH(DATA_WIDTH)
) 
axis_ipv4_tx_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .s_axis_ipv4_version(s_axis_ipv4_version),
    .s_axis_ipv4_ihl(s_axis_ipv4_ihl),
    .s_axis_ipv4_dscp(s_axis_ipv4_dscp),
    .s_axis_ipv4_ecn(s_axis_ipv4_ecn),
    .s_axis_ipv4_length(s_axis_ipv4_length),
    .s_axis_ipv4_id(s_axis_ipv4_id),
    .s_axis_ipv4_flags(s_axis_ipv4_flags),
    .s_axis_ipv4_fragment_offset(s_axis_ipv4_fragment_offset),
    .s_axis_ipv4_ttl(s_axis_ipv4_ttl),
    .s_axis_ipv4_protocol(s_axis_ipv4_protocol),
    .s_axis_ipv4_source_ip(s_axis_ipv4_source_ip),
    .s_axis_ipv4_destination_ip(s_axis_ipv4_destination_ip),
    .s_axis_ipv4_header_tvalid(s_axis_ipv4_header_tvalid),
    .s_axis_ipv4_header_tready(s_axis_ipv4_header_tready),
    .s_axis_tdata(axis_udp_tx_inst_m_axis_tdata),
    .s_axis_tvalid(axis_udp_tx_inst_m_axis_tvalid),
    .s_axis_tready(axis_ipv4_tx_inst_s_axis_tready),
    .s_axis_tlast(axis_udp_tx_inst_m_axis_tlast),
    .m_axis_tdata(axis_ipv4_tx_inst_m_axis_tdata),
    .m_axis_tvalid(axis_ipv4_tx_inst_m_axis_tvalid),
    .m_axis_tready(axis_mac_tx_inst_s_axis_tready),
    .m_axis_tlast(axis_ipv4_tx_inst_m_axis_tlast)
);

wire [DATA_WIDTH - 1:0] axis_mac_tx_inst_m_axis_tdata;
wire axis_mac_tx_inst_m_axis_tvalid;
wire axis_mac_tx_inst_m_axis_tlast;

wire axis_mac_xmii_phy_async_fifo_inst_s_axis_tready;

axis_mac_tx #(
    .DATA_WIDTH(DATA_WIDTH),
    .MIN_FRAME_LENGTH(64)
) 
axis_mac_tx_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .s_axis_eth_destination_mac(s_axis_eth_destination_mac),
    .s_axis_eth_source_mac(s_axis_eth_source_mac),
    .s_axis_eth_length(s_axis_eth_length),
    .s_axis_eth_header_tvalid(s_axis_eth_header_tvalid),
    .s_axis_eth_header_tready(s_axis_eth_header_tready),
    .s_axis_tdata(axis_ipv4_tx_inst_m_axis_tdata),
    .s_axis_tvalid(axis_ipv4_tx_inst_m_axis_tvalid),
    .s_axis_tready(axis_mac_tx_inst_s_axis_tready),
    .s_axis_tlast(axis_ipv4_tx_inst_m_axis_tlast),
    .m_axis_tdata(axis_mac_tx_inst_m_axis_tdata),
    .m_axis_tvalid(axis_mac_tx_inst_m_axis_tvalid),
    .m_axis_tready(axis_mac_xmii_phy_async_fifo_inst_s_axis_tready),
    .m_axis_tlast(axis_mac_tx_inst_m_axis_tlast)
);

wire [DATA_WIDTH - 1:0] axis_mac_xmii_phy_async_fifo_inst_m_axis_tdata;
wire axis_mac_xmii_phy_async_fifo_inst_m_axis_tvalid;
wire axis_mac_xmii_phy_async_fifo_inst_m_axis_tlast;
wire axis_mac_xmii_phy_async_fifo_inst_o_packet_ready;

wire axis_xmii_phy_tx_inst_s_axis_tready;
wire axis_xmii_phy_tx_inst_o_xmii_phy_tx_busy;

axis_mac_xmii_phy_async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .FIFO_DEPTH(FIFO_DEPTH)
) 
axis_mac_xmii_phy_async_fifo_inst (
    .s_clk(i_clk),
    .m_clk(xmii_tx_clk),
    .s_rst(i_rst),
    .m_rst(i_rst),
    .s_axis_tdata(axis_mac_tx_inst_m_axis_tdata),
    .s_axis_tvalid(axis_mac_tx_inst_m_axis_tvalid),
    .s_axis_tready(axis_mac_xmii_phy_async_fifo_inst_s_axis_tready),
    .s_axis_tlast(axis_mac_tx_inst_m_axis_tlast),
    .m_axis_tdata(axis_mac_xmii_phy_async_fifo_inst_m_axis_tdata),
    .m_axis_tvalid(axis_mac_xmii_phy_async_fifo_inst_m_axis_tvalid),
    .m_axis_tready(axis_xmii_phy_tx_inst_s_axis_tready),
    .m_axis_tlast(axis_mac_xmii_phy_async_fifo_inst_m_axis_tlast),
    .i_xmii_phy_busy(axis_xmii_phy_tx_inst_o_xmii_phy_tx_busy),
    .o_packet_ready(axis_mac_xmii_phy_async_fifo_inst_o_packet_ready)
);

axis_xmii_phy_tx #(
    .DATA_WIDTH(DATA_WIDTH),
    .XMII_WIDTH(XMII_WIDTH)
) 
axis_xmii_phy_tx_inst (
    .i_rst(i_rst),
    .s_axis_tdata(axis_mac_xmii_phy_async_fifo_inst_m_axis_tdata),
    .s_axis_tvalid(axis_mac_xmii_phy_async_fifo_inst_m_axis_tvalid),
    .s_axis_tready(axis_xmii_phy_tx_inst_s_axis_tready),
    .s_axis_tlast(axis_mac_xmii_phy_async_fifo_inst_m_axis_tlast),
    .xmii_tx_clk(xmii_tx_clk),
    .xmii_txd(xmii_txd),
    .xmii_tx_en(xmii_tx_en),
    .xmii_tx_er(xmii_tx_er),
    .i_packet_ready(axis_mac_xmii_phy_async_fifo_inst_o_packet_ready),
    .o_xmii_phy_tx_busy(axis_xmii_phy_tx_inst_o_xmii_phy_tx_busy)
);

endmodule
