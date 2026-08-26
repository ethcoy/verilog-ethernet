module axis_mac_tx #(
    parameter DATA_WIDTH = 8,
    parameter MIN_FRAME_LENGTH = 64
) (
    input wire logic i_clk,
    input wire logic i_rst,

    input wire logic [47:0] s_axis_eth_destination_addr,
    input wire logic [47:0] s_axis_eth_source_addr,
    input wire logic [15:0] s_axis_eth_type,
    input wire logic s_axis_eth_tvalid,
    output wire logic s_axis_eth_tready,

    input wire logic [DATA_WIDTH - 1:0] s_axis_tdata,
    input wire logic s_axis_tvalid,
    output wire logic s_axis_tready,
    input wire logic s_axis_tlast,

    output wire logic [DATA_WIDTH - 1:0] m_axis_tdata,
    output wire logic m_axis_tvalid,
    input wire logic m_axis_tready,
    output wire m_axis_tlast
);

localparam MIN_FRAME_LENGTH_ADJUSTED = MIN_FRAME_LENGTH - 6 - 6 - 2 - 4;

logic [111:0] s_axis_eth_header_reg = {112{1'b0}};
logic s_axis_eth_tready_reg = 1'b0;

logic [DATA_WIDTH - 1:0] s_axis_tdata_reg = {DATA_WIDTH{1'b0}};
logic s_axis_tready_reg = 1'b0;
logic s_axis_tlast_reg = 1'b0;

logic [DATA_WIDTH - 1:0] m_axis_tdata_reg = {DATA_WIDTH{1'b0}};
logic m_axis_tvalid_reg = 1'b0;
logic m_axis_tlast_reg = 1'b0;

logic [111:0] s_axis_eth_header_next;
logic s_axis_eth_tready_next;

logic [DATA_WIDTH - 1:0] s_axis_tdata_next;
logic s_axis_tready_next;
logic s_axis_tlast_next;

logic [DATA_WIDTH - 1:0] m_axis_tdata_next;
logic m_axis_tvalid_next;
logic m_axis_tlast_next;

assign s_axis_eth_tready = s_axis_eth_tready_reg;

assign s_axis_tready = s_axis_tready_reg;

assign m_axis_tdata = m_axis_tdata_reg;
assign m_axis_tvalid = m_axis_tvalid_reg;
assign m_axis_tlast = m_axis_tlast_reg;

localparam STATE_ETHERNET_IDLE = 0;
localparam STATE_ETHERNET_PREAMBLE_SFD = 1;
localparam STATE_ETHERNET_HEADER_AND_TYPE = 2;
localparam STATE_ETHERNET_DATA = 3;
localparam STATE_ETHERNET_PAD = 4;
localparam STATE_ETHERNET_CRC_REG = 5;
localparam STATE_ETHERNET_CRC = 6;
localparam STATE_ETHERNET_IPG = 7;

logic [2:0] state_reg = STATE_ETHERNET_IDLE;
logic [2:0] state_next;

logic [15:0] count_reg = 16'b0;
logic [15:0] count_next;

logic [31:0] crc_reg = 32'b0;
logic [31:0] crc_next;
wire [31:0] crc_wire;

logic crc_data_valid_reg = 1'b0;
logic crc_data_valid_next;

logic crc_rst_reg = 1'b0;
logic crc_rst_next;

localparam ETH_PRE = 8'hAA;
localparam ETH_SFD = 8'hAB;

crc #(
    .c_DATA_WIDTH(DATA_WIDTH),
    .c_GEN_POLY(32'h04c11db7),
    .c_GEN_POLY_WIDTH(32),
    .c_INITIAL_CRC_VALUE({32{1'b1}}),
    .c_REVERSE_INPUT_BIT_ORDER(1),
    .c_REVERSE_OUTPUT_BIT_ORDER(1),
    .c_COMPLEMENT_OUTPUT(1)
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
            if (s_axis_eth_tvalid && s_axis_eth_tready) begin
                s_axis_eth_header_next = {s_axis_eth_destination_addr, s_axis_eth_source_addr, s_axis_eth_type};
                s_axis_eth_tready_next = 1'b0;
                m_axis_tdata_next = ETH_PRE;
                m_axis_tvalid_next = 1'b1;
                count_next = 16'd0;
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
                    count_next = 16'd0;
                    state_next = STATE_ETHERNET_HEADER_AND_TYPE;
                end
            end
        end

        STATE_ETHERNET_HEADER_AND_TYPE: begin
            if (m_axis_tvalid && m_axis_tready) begin
                s_axis_eth_header_next = s_axis_eth_header_reg << 8;
                m_axis_tdata_next = s_axis_eth_header_next[111:104];
                count_next = count_reg + 1'b1;
                if (count_next == 14) begin
                    s_axis_tready_next = 1'b1;
                    m_axis_tvalid_next = 1'b0;
                    count_next = 16'd0;
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
                        m_axis_tdata_next = 8'd0;
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
                    count_next = 16'd0;
                    m_axis_tvalid_next = 1'b0;
                    state_next = STATE_ETHERNET_CRC_REG;
                end
            end
        end

        STATE_ETHERNET_CRC_REG: begin
            state_next = STATE_ETHERNET_CRC;
            count_next = 16'd0;
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
                crc_next = crc_reg << 8;
                for (integer i = 0; i < DATA_WIDTH; i = i + 1) begin
                    m_axis_tdata_next[i] = crc_next[31 - i];
                end

                if (count_next == 16'd4) begin
                    state_next = STATE_ETHERNET_IPG;
                    m_axis_tdata_next = 8'd0;
                    count_next = 16'd0;
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