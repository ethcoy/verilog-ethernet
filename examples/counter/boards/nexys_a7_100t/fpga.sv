module fpga #(
    parameter XMII_WIDTH = 2
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // xMII Tx interface
    output wire logic xmii_tx_clk_45,
    output wire logic [XMII_WIDTH - 1:0] xmii_txd,
    output wire logic xmii_tx_en,
    
    output wire logic [1:0] xmii_rxd,
    // Need to actually add resets to each module...
    // When reset is asserted, do not look at xmii_crsdv
    output wire logic xmii_crsdv,
    output wire logic xmii_rst
);

assign xmii_rxd[0] = (xmii_rst == 0) ? 1'b1 : 1'bz;
assign xmii_rxd[1] = (xmii_rst == 0) ? 1'b1 : 1'bz;
assign xmii_crsdv = (xmii_rst == 0) ? 1'b1 : 1'bz;

assign xmii_rst = i_rst;

wire xmii_tx_clk;
wire clk_out3;

clk_wiz_0 
clk_wiz_0_inst (
    .mmcm_xmii_tx_clk_0(xmii_tx_clk),
    .mmcm_xmii_tx_clk_45(xmii_tx_clk_45),
    .clk_out3(clk_out3),
    .clk_100mhz_in(i_clk)
 );

axis_tcp_ip_stack #(
    .XMII_WIDTH(XMII_WIDTH)
) 
axis_tcp_ip_stack_inst (
    .i_clk(clk_out3),
    .i_rst(i_rst),
    .xmii_tx_clk(xmii_tx_clk),
    .xmii_txd(xmii_txd),
    .xmii_tx_en(xmii_tx_en)
);


endmodule