import lab5_pkg::*;

module parser (
    input logic clk, reset_n,
    input packet_cfg_t pkt_data,
    input logic pkt_valid,
    output rx_parsed_t rx_parsed_data,
    output logic msg_valid // FOR TB!
);

    localparam [DATA_WIDTH-1:0] ZERO_ASCII = 8'h30;
    localparam [DATA_WIDTH-1:0] NINE_ASCII = 8'h39;

    localparam MAX_VALUE = 1000; // values from 0-999 so 1000 number options
    localparam ASCII_TO_BIN_WIDTH = $clog2(MAX_VALUE);

    localparam [ASCII_TO_BIN_WIDTH-1:0] HUNDRED = 100, TEN = 10;

    // 1. check data type in each place
    logic row_index_check; assign row_index_check = (pkt_data.r == R_VAL);
    logic comma0_check; assign comma0_check = (pkt_data.comma0 == COMMA_VAL);
    logic col_index_check; assign col_index_check = (pkt_data.c == C_VAL);
    logic comma1_check; assign comma1_check = (pkt_data.comma1 == COMMA_VAL);
    logic v_check; assign v_check = (pkt_data.v == V_VAL);

    genvar i;
    logic [DIGITS-1:0] row_idx_val_check, col_idx_val_check, value_check; 
    logic [ASCII_TO_BIN_WIDTH-1:0] row_bin, col_bin, value_bin;

    localparam PAD = ASCII_TO_BIN_WIDTH - DIG_IN_WIDTH;
    logic [DIGITS-1:0][ASCII_TO_BIN_WIDTH-1:0] row_dig, col_dig, value_dig;


    generate
        for (i = 0; i < DIGITS; i++) begin : decimal_check
            assign row_idx_val_check[i] = (pkt_data.row_index[i] >= ZERO_ASCII) && (pkt_data.row_index[i] <= NINE_ASCII);
            assign col_idx_val_check[i] = (pkt_data.col_index[i] >= ZERO_ASCII) && (pkt_data.col_index[i] <= NINE_ASCII);
            assign value_check[i] = (pkt_data.value[i] >= ZERO_ASCII) && (pkt_data.value[i] <= NINE_ASCII);

            assign row_dig[i] = {{PAD{1'b0}}, pkt_data.row_index[i][DIG_IN_WIDTH-1:0]};
            assign col_dig[i] = {{PAD{1'b0}}, pkt_data.col_index[i][DIG_IN_WIDTH-1:0]};
            assign value_dig[i] = {{PAD{1'b0}}, pkt_data.value[i][DIG_IN_WIDTH-1:0]};
        end
    endgenerate

    // 2. convert ascii to digits
    // Because zero in ascii is 0x30, one is 0x31 ... can take only the lower nibble
    assign row_bin = row_dig[2]*HUNDRED + row_dig[1]*TEN + row_dig[0];
    assign col_bin = col_dig[2]*HUNDRED + col_dig[1]*TEN + col_dig[0];
    assign value_bin = value_dig[2]*HUNDRED + value_dig[1]*TEN + value_dig[0];

    // 3. in_range check
    localparam [ASCII_TO_BIN_WIDTH-1:0] SAT_VAL = 2**DATA_WIDTH - 1;
    logic row_in_range, col_in_range, value_in_range;
    assign row_in_range = (row_bin <= SAT_VAL);
    assign col_in_range = (col_bin <= SAT_VAL);
    assign value_in_range = (value_bin <= SAT_VAL);

    logic parse_valid; assign parse_valid = row_index_check & comma0_check & col_index_check & comma1_check & v_check & (&row_idx_val_check) & (&col_idx_val_check) & (&value_check) & row_in_range & col_in_range & value_in_range;
    assign msg_valid =  pkt_valid & parse_valid;

    always_ff @(posedge clk) begin
        if (!reset_n) rx_parsed_data <= '0;
        else if (msg_valid) rx_parsed_data <= {row_bin[DATA_WIDTH-1:0], col_bin[DATA_WIDTH-1:0], value_bin[DATA_WIDTH-1:0]};
    end


endmodule
