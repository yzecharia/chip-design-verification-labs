import lab5_pkg::*;

module rx_mac (
    input logic clk, reset_n,
    input logic done,
    input logic [DATA_WIDTH-1:0] data_in,
    output packet_cfg_t pkt_data,
    output logic pkt_valid
);

localparam PACKET_SIZE = 16;
localparam PACKET_CNT_BITS = $clog2(PACKET_SIZE);

rx_mac_state_t state, next;

logic first_key; assign first_key = (data_in == MSG_START_VAL);
logic last_key; assign last_key = (data_in == MSG_CLOSE_VAL);

localparam [PACKET_CNT_BITS-1:0] ONE = 1;
localparam [PACKET_CNT_BITS-1:0] LAST_INDEX = (PACKET_SIZE-1) - 1;
logic [PACKET_CNT_BITS-1:0] cnt;
logic last_byte; assign last_byte = (cnt == LAST_INDEX);
always_ff @(posedge clk) begin
    if (!reset_n) cnt <= '0;
    else if (((state == RX_MAC_IDLE) & first_key & done) | ((state == RX_MAC_COUNT) & done & first_key)) cnt <= '0;
    else if ((state == RX_MAC_COUNT) & done) cnt <= cnt + ONE;
end

always_ff @(posedge clk) begin
    if (!reset_n) state <= RX_MAC_IDLE;
    else state <= next;
end

always_comb begin
    next = state;
    unique case(state)
        RX_MAC_IDLE: next = (first_key & done) ? RX_MAC_COUNT : RX_MAC_IDLE;
        RX_MAC_COUNT: next = (done & ((last_byte & !first_key) | last_key)) ? RX_MAC_IDLE : RX_MAC_COUNT;
        default: next = state;
    endcase
end

always_ff @(posedge clk) begin
    if (!reset_n) pkt_data <= '0;
    else if ((((state == RX_MAC_IDLE) & first_key) | (state == RX_MAC_COUNT)) & done) pkt_data <= {pkt_data[((PACKET_SIZE-1)*DATA_WIDTH)-1:0], data_in};
end

always_ff @(posedge clk) begin
    if (!reset_n) pkt_valid <= '0;
    else if ((state == RX_MAC_COUNT) & last_key & last_byte & done) pkt_valid <= '1;
    else pkt_valid <= '0;
end



endmodule
