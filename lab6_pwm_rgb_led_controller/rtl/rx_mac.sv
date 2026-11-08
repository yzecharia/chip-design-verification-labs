import lab6_pkg::*;

module rx_mac (
    input logic clk, reset_n,
    input logic done,
    input logic [DATA_WIDTH-1:0] data_in,
    output packet_cfg_t pkt_data,
    output logic pkt_valid
);

    rx_mac_state_t state, next;
    
    localparam [DATA_WIDTH-1:0] ASCII_ZERO = 8'h30;
    localparam [DATA_WIDTH-1:0] ASCII_NINE = 8'h39;
    localparam [DATA_WIDTH-1:0] ASCII_A_BIG = 8'h41;
    localparam [DATA_WIDTH-1:0] ASCII_Z_BIG = 8'h5A;
    localparam [DATA_WIDTH-1:0] ASCII_A_SMALL = 8'h61;
    localparam [DATA_WIDTH-1:0] ASCII_Z_SMALL = 8'h7A;

    logic is_big_char; assign is_big_char = (data_in >= ASCII_A_BIG) & (data_in <= ASCII_Z_BIG);
    logic is_small_char; assign is_small_char = (data_in >= ASCII_A_SMALL) & (data_in <= ASCII_Z_SMALL);

    logic is_comma; assign is_comma = (data_in == COMMA_VAL);
    logic is_start; assign is_start = (data_in == MSG_START_VAL);
    logic is_end; assign is_end = (data_in == MSG_CLOSE_VAL);
    logic is_value; assign is_value = (data_in >= ASCII_ZERO) & (data_in <= ASCII_NINE);
    logic is_opcode; assign is_opcode = is_big_char | is_small_char;

    localparam VALUE_WIDTH = $clog2(NUM_OF_VALUES);
    logic [VALUE_WIDTH-1:0] value_cnt;
    logic value_done; assign value_done = (value_cnt == NUM_OF_VALUES - 1);
    always_ff @(posedge clk) begin
        if (!reset_n) value_cnt <= '0;
        else if ((state == RX_MAC_OPCODE) & done & is_opcode) value_cnt <= '0;
        else if ((state == (RX_MAC_VALUE)) & done & is_value) value_cnt <= value_cnt + 1;
    end

    localparam GROUP_WIDTH = $clog2(MAX_GROUPS);
    logic [GROUP_WIDTH-1:0] group_cnt;
    logic max_group; assign max_group = (group_cnt == MAX_GROUPS - 1);
    always_ff @(posedge clk) begin
        if (!reset_n) group_cnt <= '0;
        else if (done & is_start) group_cnt <= '0;
        else if ((state == RX_MAC_DONE_NEXT) & done & is_comma & !max_group) group_cnt <= group_cnt + 1;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) state <= RX_MAC_IDLE;
        else state <= next;
    end

    always_comb begin 
        next = state;
        unique case(state)
            RX_MAC_IDLE: next = (done & is_start) ? RX_MAC_OPCODE : RX_MAC_IDLE;
            RX_MAC_OPCODE: begin
                if (done) begin
                    if (is_start) next = RX_MAC_OPCODE;
                    else if (is_opcode) next = RX_MAC_VALUE;
                    else next = RX_MAC_IDLE;
                end
            end
            RX_MAC_VALUE: begin
                if (done) begin
                    if (is_value) next = (value_done) ? RX_MAC_DONE_NEXT : RX_MAC_VALUE;
                    else next = (is_start) ? RX_MAC_OPCODE : RX_MAC_IDLE; 
                end 
            end
            RX_MAC_DONE_NEXT: begin
                if (done) begin
                    if ((!is_comma & !is_start) | (max_group & is_comma)) next = RX_MAC_IDLE;
                    else if (is_start | (is_comma & !max_group)) next = RX_MAC_OPCODE;
                end
            end
            default: next = RX_MAC_IDLE;
        endcase
    end


    // MAX_GROUPS is 3, NUM_OF_VALUES = 3; 2 start and end, opcodes as max_group, values the amount of max_group, and commans is max_group - 1
    // 2 + 3 opcode + 3*3values + 2 commas
    // => PACKET_SIZE = 2 + MAX_GROUPS + MAX_GROUPS*NUM_OF_VALUES + (MAX_GROUPS-1) = 2 + 3 + 9 + 2 = 16
    localparam CALC_PACKET_SIZE = 2 + MAX_GROUPS*(2 + NUM_OF_VALUES) - 1;
    always_ff @(posedge clk) begin
        if (!reset_n) pkt_data <= '0;
        else if (done & is_start) pkt_data <= {{(CALC_PACKET_SIZE-1)*DATA_WIDTH{1'b0}}, MSG_START_VAL};
        else if (done & (((state == RX_MAC_OPCODE) & is_opcode) | ((state == RX_MAC_VALUE) & is_value) | ((state == RX_MAC_DONE_NEXT) & ((is_comma & !max_group) | is_end)))) pkt_data <= {pkt_data[(CALC_PACKET_SIZE-1)*DATA_WIDTH-1:0], data_in};
    end

    always_ff @(posedge clk) begin
        if (!reset_n) pkt_valid <= '0;
        else pkt_valid <= (state == RX_MAC_DONE_NEXT) & done & is_end;
    end

endmodule
