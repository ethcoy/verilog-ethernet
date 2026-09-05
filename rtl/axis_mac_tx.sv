module axis_mac_tx #(
    parameter DATA_WIDTH = 8,
    parameter MIN_FRAME_LENGTH = 64
) (
    input wire logic i_clk,
    input wire logic i_rst,

    // Ethernet AXI-Stream header sink interface
    input wire logic [47:0] s_axis_eth_destination_mac,
    input wire logic [47:0] s_axis_eth_source_mac,
    input wire logic [15:0] s_axis_eth_length,
    input wire logic s_axis_eth_header_tvalid,
    output wire logic s_axis_eth_header_tready,

    // Ethernet AXI-Stream data sink interface
    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    // Ethernet AXI-Stream data source interface
    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    input wire logic m_axis_tready,
    output wire m_axis_tlast
);

localparam MIN_FRAME_LENGTH_ADJUSTED = MIN_FRAME_LENGTH - 6 - 6 - 2 - 4;

logic [111:0] s_axis_eth_header_reg = '0, s_axis_eth_header_next;
logic s_axis_eth_tready_reg = 1'b0, s_axis_eth_tready_next;

logic [DATA_WIDTH - 1:0] s_axis_tdata_reg = '0, s_axis_tdata_next;
logic s_axis_tready_reg = 1'b0, s_axis_tready_next;
logic s_axis_tlast_reg = 1'b0, s_axis_tlast_next;

logic [DATA_WIDTH - 1:0] m_axis_tdata_reg = '0, m_axis_tdata_next;
logic m_axis_tvalid_reg = 1'b0, m_axis_tvalid_next;
logic m_axis_tlast_reg = 1'b0, m_axis_tlast_next;

assign s_axis_eth_header_tready = s_axis_eth_tready_reg;

assign s_axis_tready = s_axis_tready_reg;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

typedef enum logic [2:0] {
    STATE_ETHERNET_IDLE,
    STATE_ETHERNET_PREAMBLE_SFD,
    STATE_ETHERNET_HEADER_AND_TYPE,
    STATE_ETHERNET_DATA,
    STATE_ETHERNET_PAD,
    STATE_ETHERNET_CRC_REG,
    STATE_ETHERNET_CRC,
    STATE_ETHERNET_IPG
} state_t;

state_t state_reg = STATE_ETHERNET_IDLE, state_next;

logic [15:0] count_reg = '0, count_next;

logic [31:0] crc_reg = '0, crc_next;

wire [31:0] crc_wire;

logic crc_data_valid_reg = 1'b0, crc_data_valid_next;

logic crc_rst_reg = 1'b0, crc_rst_next;

localparam ETH_PRE = 8'h55;
localparam ETH_SFD = 8'hD5;

crc #(
    .DATA_WIDTH(DATA_WIDTH),
    .GEN_POLY(32'h04c11db7),
    .GEN_POLY_WIDTH(32),
    .INITIAL_CRC_VALUE({32{1'b1}}),
    .REVERSE_INPUT_BIT_ORDER(1),
    .REVERSE_OUTPUT_BIT_ORDER(1),
    .COMPLEMENT_OUTPUT(1)
)
crc_inst (
    .i_clk(i_clk),
    .i_rst(crc_rst_reg),
    .i_data(m_axis_tdata),
    .i_data_valid(m_axis_tvalid && m_axis_tready && crc_data_valid_reg),
    .o_crc(crc_wire)
);

always_comb begin
    state_next = state_reg;

    s_axis_eth_header_next = s_axis_eth_header_reg;
    s_axis_eth_tready_next = s_axis_eth_tready_reg;

    s_axis_tdata_next = s_axis_tdata_reg;
    s_axis_tready_next = s_axis_tready_reg;
    s_axis_tlast_next = s_axis_tlast_reg;

    m_axis_tdata_next = m_axis_tdata_reg;
    m_axis_tvalid_next = m_axis_tvalid_reg;
    m_axis_tlast_next = m_axis_tlast_reg;

    count_next = count_reg;

    crc_next = crc_reg;

    crc_data_valid_next = crc_data_valid_reg;

    crc_rst_next = crc_rst_reg;

    case (state_reg)
        STATE_ETHERNET_IDLE: begin
            s_axis_eth_tready_next = 1'b1;
            if (s_axis_eth_header_tvalid && s_axis_eth_header_tready) begin
                s_axis_eth_header_next = {s_axis_eth_destination_mac, s_axis_eth_source_mac, s_axis_eth_length};
                s_axis_eth_tready_next = 1'b0;
                m_axis_tdata_next = ETH_PRE;
                m_axis_tvalid_next = 1'b1;
                count_next = '0;
                state_next = STATE_ETHERNET_PREAMBLE_SFD;
            end
        end

        STATE_ETHERNET_PREAMBLE_SFD: begin
            if (m_axis_tvalid && m_axis_tready) begin
                count_next = count_reg + 1'b1;
                if (count_next == 7) begin
                    m_axis_tdata_next = ETH_SFD;
                end

                if (count_next == 8) begin
                    crc_data_valid_next = 1'b1;
                    m_axis_tdata_next = s_axis_eth_header_reg[111:104];
                    count_next = '0;
                    state_next = STATE_ETHERNET_HEADER_AND_TYPE;
                end
            end
        end

        STATE_ETHERNET_HEADER_AND_TYPE: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_eth_header_next = s_axis_eth_header_reg << DATA_WIDTH;
                m_axis_tdata_next = s_axis_eth_header_next[111:104];
                count_next = count_reg + 1'b1;
                if (count_next == 14) begin
                    s_axis_tready_next = 1'b1;
                    m_axis_tvalid_next = 1'b0;
                    count_next = '0;
                    state_next = STATE_ETHERNET_DATA;
                end
            end
        end

        STATE_ETHERNET_DATA: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_tready_next = 1'b1;
                m_axis_tvalid_next = 1'b0;
                count_next = count_reg + 1'b1;
                if (s_axis_tlast_reg) begin
                    s_axis_tready_next = 1'b0;
                    state_next = STATE_ETHERNET_CRC_REG;
                    if (count_next < MIN_FRAME_LENGTH_ADJUSTED) begin
                        m_axis_tdata_next = '0;
                        m_axis_tvalid_next = 1'b1;
                        state_next = STATE_ETHERNET_PAD;
                    end
                end
            end

            if (s_axis_tvalid && s_axis_tready) begin
                s_axis_tready_next = 1'b0;
                s_axis_tlast_next = s_axis_tlast;
                m_axis_tdata_next = s_axis_tdata;
                m_axis_tvalid_next = 1'b1;
            end
        end

        STATE_ETHERNET_PAD: begin
            if (m_axis_tvalid && m_axis_tready) begin
                count_next = count_reg + 1'b1;
                if (count_next >= MIN_FRAME_LENGTH_ADJUSTED) begin
                    count_next = '0;
                    m_axis_tvalid_next = 1'b0;
                    state_next = STATE_ETHERNET_CRC_REG;
                end
            end
        end

        STATE_ETHERNET_CRC_REG: begin
            state_next = STATE_ETHERNET_CRC;
            count_next = '0;
            crc_next = crc_wire;
            crc_data_valid_next = 1'b0;
            crc_rst_next = 1'b1;
            m_axis_tvalid_next = 1'b1;
            for (integer i = 0; i < DATA_WIDTH; i = i + 1) begin
                m_axis_tdata_next[i] = crc_next[31 - i];
            end
        end

        STATE_ETHERNET_CRC: begin
            crc_rst_next = 1'b0;
            if (m_axis_tvalid && m_axis_tready) begin
                count_next = count_reg + 1'b1;
                crc_next = crc_reg << DATA_WIDTH;
                for (integer i = 0; i < DATA_WIDTH; i = i + 1) begin
                    m_axis_tdata_next[i] = crc_next[31 - i];
                end

                if (count_next == 4) begin
                    state_next = STATE_ETHERNET_IPG;
                    m_axis_tdata_next = '0;
                    count_next = '0;
                end
            end
        end

        STATE_ETHERNET_IPG: begin
            if (m_axis_tvalid && m_axis_tready) begin
                count_next = count_reg + 1'b1;
                if (count_next == 11) begin
                    m_axis_tlast_next = 1'b1;
                end

                if (count_next == 12) begin
                    m_axis_tvalid_next = 1'b0;
                    m_axis_tlast_next = 1'b0;
                    state_next = STATE_ETHERNET_IDLE;
                end
            end
        end

        default: begin
            state_next = STATE_ETHERNET_IDLE;
        end
    endcase
end

always_ff @(posedge i_clk) begin
    state_reg <= state_next;

    s_axis_eth_header_reg <= s_axis_eth_header_next;
    s_axis_eth_tready_reg <= s_axis_eth_tready_next;
    s_axis_tdata_reg <= s_axis_tdata_next;
    s_axis_tready_reg <= s_axis_tready_next;
    s_axis_tlast_reg <= s_axis_tlast_next;

    m_axis_tdata_reg <= m_axis_tdata_next;
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tlast_reg <= m_axis_tlast_next;

    count_reg <= count_next;

    crc_reg <= crc_next;

    crc_data_valid_reg <= crc_data_valid_next;

    crc_rst_reg <= crc_rst_next;
end

endmodule
