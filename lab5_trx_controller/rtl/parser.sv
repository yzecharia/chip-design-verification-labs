import lab5_pkg::*;

module parser (
    input logic clk, reset_n,
    input packet_cfg_t pkt_data,
    input logic pkt_valid,
    output rx_parsed_t rx_parsed_data,
    output logic msg_valid // FOR TB!
);

    localparam MAX_VALUE = 1000; // values from 0-999 so 1000 number options
    localparam ASCII_TO_BIN_WIDTH = $clog2(MAX_VALUE);
    localparam [ASCII_TO_BIN_WIDTH-1:0] HUNDRED = 100, TEN = 10;
    localparam [ASCII_TO_BIN_WIDTH-1:0] MAX_PIXEL_VAL = 255;

    logic valid_r; assign valid_r = (pkt_data.r == R_VAL) | (pkt_data.r == R_SMALL_VAL);
    logic valid_c; assign valid_c = (pkt_data.c == C_VAL) | (pkt_data.c == C_SMALL_VAL);
    logic valid_v; assign valid_v = (pkt_data.v == V_VAL) | (pkt_data.v == V_SMALL_VAL);

    // No {, } check because it is already checked in rx_mac, and if small message then c and v and r wont be in place so msg not valid
    logic valid_opcode; assign valid_opcode = valid_r & valid_c & valid_v;
    logic valid_comma; assign valid_comma = (pkt_data.comma0 == COMMA_VAL) & (pkt_data.comma1 == COMMA_VAL);

    // ASCII nums = 0x30 - 0x39 so can take only bottom nibble
    logic [ASCII_TO_BIN_WIDTH-1:0] row, col, val;
    assign row = pkt_data.row_index[2][3:0] * HUNDRED + pkt_data.row_index[1][3:0] * TEN + pkt_data.row_index[0][3:0];
    assign col = pkt_data.col_index[2][3:0] * HUNDRED + pkt_data.col_index[1][3:0] * TEN + pkt_data.col_index[0][3:0];
    assign val = pkt_data.value[2][3:0] * HUNDRED + pkt_data.value[1][3:0] * TEN + pkt_data.value[0][3:0];

    logic bad_index; assign bad_index = (row > 255) | (col > 255) | (val > MAX_PIXEL_VAL);
    logic msg_valid_comb; assign msg_valid_comb = valid_comma & valid_opcode & !bad_index;

    always_ff @(posedge clk) begin
        if (!reset_n) msg_valid <= '0;
        else msg_valid <= pkt_valid & msg_valid_comb;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) rx_parsed_data <= '0;
        else if (pkt_valid & msg_valid_comb) rx_parsed_data <= {row[DATA_WIDTH-1:0], col[DATA_WIDTH-1:0], val[DATA_WIDTH-1:0]};
    end

endmodule
