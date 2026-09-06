module fpga #(
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

axis_tcp_ip_stack #(
    .XMII_WIDTH(XMII_WIDTH)
) 
axis_tcp_ip_stack_inst (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .xmii_tx_clk(xmii_tx_clk),
    .xmii_txd(xmii_txd),
    .xmii_tx_en(xmii_tx_en),
    .xmii_tx_er(xmii_tx_er)
);


endmodule