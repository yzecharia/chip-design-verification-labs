import lab6_pkg::*;

module parser (
    input logic clk, reset_n,
    input packet_cfg_t pkt_data,
    input logic pkt_valid,
    output pixel_parsed_t pixel_parsed_data,
    output logic led_parsed_data,
    output logic pixel_valid, // FOR TB!
    output logic led_valid
);

    localparam MAX_VALUE = 1000; // values from 0-999 so 1000 number options
    localparam ASCII_TO_BIN_WIDTH = $clog2(MAX_VALUE);
    localparam [ASCII_TO_BIN_WIDTH-1:0] HUNDRED = 100, TEN = 10;
    localparam [ASCII_TO_BIN_WIDTH-1:0] MAX_PIXEL_VAL = 255;
    localparam [ASCII_TO_BIN_WIDTH-1:0] LED16_VAL = 16, LED17_VAL = 17;

    localparam SHORT_MSG_BYTES = 6;
    localparam PKT_WIDTH = PACKET_SIZE * DATA_WIDTH;
    localparam SHORT_MSG_PAD_LSB = SHORT_MSG_BYTES * DATA_WIDTH;


    logic valid_r; assign valid_r = (pkt_data.op_2 == R_VAL) | (pkt_data.op_2 == R_SMALL_VAL);
    logic valid_g; assign valid_g = (pkt_data.op_1 == G_VAL) | (pkt_data.op_1 == G_SMALL_VAL);
    logic valid_b; assign valid_b = (pkt_data.op_0 == B_VAL) | (pkt_data.op_0 == B_SMALL_VAL);
    logic valid_l; assign valid_l = (pkt_data.op_0 == L_VAL) | (pkt_data.op_0 == L_SMALL_VAL);


    // No {, } check because it is already checked in rx_mac, and if small message then c and v and r wont be in place so msg not valid

    logic valid_color_op; assign valid_color_op = valid_r & valid_g & valid_b;
    logic valid_led_op; assign valid_led_op = valid_l & (pkt_data[PKT_WIDTH-1:SHORT_MSG_PAD_LSB] == '0);

    // ASCII nums = 0x30 - 0x39 so can take only bottom nibble
    logic [ASCII_TO_BIN_WIDTH-1:0] value_2, value_1, value_0;
    assign value_2 = pkt_data.value_2[2][3:0] * HUNDRED + pkt_data.value_2[1][3:0] * TEN + pkt_data.value_2[0][3:0];
    assign value_1 = pkt_data.value_1[2][3:0] * HUNDRED + pkt_data.value_1[1][3:0] * TEN + pkt_data.value_1[0][3:0];
    assign value_0 = pkt_data.value_0[2][3:0] * HUNDRED + pkt_data.value_0[1][3:0] * TEN + pkt_data.value_0[0][3:0];

    logic bad_pixel_value; assign bad_pixel_value = ((value_2 > MAX_PIXEL_VAL) | (value_1 > MAX_PIXEL_VAL) | (value_0 > MAX_PIXEL_VAL)) & valid_color_op;
    logic bad_led_value; assign bad_led_value = ((value_0 != LED16_VAL) & (value_0 != LED17_VAL)) & valid_led_op;

    logic pixel_msg_valid_comb; assign pixel_msg_valid_comb = (valid_color_op & !bad_pixel_value);
    logic led_msg_valid_comb; assign led_msg_valid_comb = (valid_led_op & !bad_led_value);

    always_ff @(posedge clk) begin
        if (!reset_n) pixel_valid <= '0;
        else pixel_valid <= pkt_valid & pixel_msg_valid_comb;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) led_valid <= '0;
        else led_valid <= pkt_valid & led_msg_valid_comb;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) pixel_parsed_data <= '0;
        else if (pkt_valid & pixel_msg_valid_comb) pixel_parsed_data <= {value_2[DATA_WIDTH-1:0], value_1[DATA_WIDTH-1:0], value_0[DATA_WIDTH-1:0]};
    end

    always_ff @(posedge clk) begin
        if (!reset_n) led_parsed_data <= '0;
        else led_parsed_data <= (pkt_valid & led_msg_valid_comb & (value_0 == LED17_VAL));
    end


endmodule
