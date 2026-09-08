module temp_top (
    input wire i_clk,
    
    output wire logic xmii_tx_clk_45,
    output wire logic [1:0] xmii_txd,
    output wire logic xmii_tx_en
);

wire xmii_tx_clk;

temp 
temp_inst (
    .i_clk(i_clk),
    .xmii_tx_clk(xmii_tx_clk),
    .xmii_txd(xmii_txd),
    .xmii_tx_en(xmii_tx_en)
);

clk_wiz_0 
clk_wiz_0_inst (
    .mmcm_xmii_tx_clk_0(xmii_tx_clk),
    .mmcm_xmii_tx_clk_45(xmii_tx_clk_45),
    .clk_100mhz_in(i_clk)
 );

endmodule