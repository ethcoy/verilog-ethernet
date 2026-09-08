module axis_async_fifo_test_top (
    input wire i_clk,
    
    output wire [15:0] o_leds
);

wire xmii_tx_clk_45;

axis_async_fifo_test #(
    .DATA_WIDTH(16),
    .CYCLE_DELAY(1000000)
) 
axis_async_fifo_test_inst (
    .s_clk(i_clk),
    .m_clk(xmii_tx_clk_45),
    .o_leds(o_leds)
);

clk_wiz_0 
clk_wiz_0_inst (
    .mmcm_xmii_tx_clk_0(xmii_tx_clk),
    .mmcm_xmii_tx_clk_45(xmii_tx_clk_45),
    .clk_100mhz_in(i_clk)
 );

endmodule