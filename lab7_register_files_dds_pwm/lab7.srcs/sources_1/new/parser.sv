import lab7_pkg::*;

module parser (
    input logic clk, reset_n,
    input packet_cfg_t pkt_data,
    input logic pkt_valid,
    output parsed_msg_t msg
);

    /*
        parser can now recive 4 valid msg types:
            1. {WXXX,VXXX,VXXX} - opcodes are W and V, first value in V's is dont care (inforce 0)
            2. {RXXX} - opcodes are R
            3. {RXXX,GXXX,BXXX} - opcodes are R, G and B
            4. {LXXX} - opcode is L. data is 1 for 017 and 0 for 016;

        Need to support all msg_types.
        Need to check for valid opcodes per msg_type
        Need to arrange msg_data to pass on

        output data type should be: parsed_msg_t

        data in type is: pcket_cfg_t

    */

    localparam MAX_VALUE = 1000; // values from 0-999 so 1000 number options
    localparam ASCII_TO_BIN_WIDTH = $clog2(MAX_VALUE);
    localparam [ASCII_TO_BIN_WIDTH-1:0] HUNDRED = 100, TEN = 10;
    localparam [ASCII_TO_BIN_WIDTH-1:0] MAX_PIXEL_VAL = 255;
    localparam [ASCII_TO_BIN_WIDTH-1:0] LED16_VAL = 16, LED17_VAL = 17;

    localparam SHORT_MSG_BYTES = 6;
    localparam PKT_WIDTH = PACKET_SIZE * DATA_WIDTH;
    localparam SHORT_MSG_PAD_LSB = SHORT_MSG_BYTES * DATA_WIDTH;

    localparam [DATA_WIDTH-1:0] ASCII_ZERO = 8'h30;
    localparam [DATA_WIDTH-1:0] ASCII_NINE = 8'h39;

    parsed_msg_t msg_temp;

    logic valid_w_wr; assign valid_w_wr = (pkt_data.op_2 == W_VAL) || (pkt_data.op_2 == W_VAL_SMALL);
    logic valid_v_wr_rd_op1; assign valid_v_wr_rd_op1 = (pkt_data.op_1 == V_VAL) || (pkt_data.op_1 == V_VAL_SMALL);
    logic valid_v_wr_rd_op0; assign valid_v_wr_rd_op0 = (pkt_data.op_0 == V_VAL) || (pkt_data.op_0 == V_VAL_SMALL);
    logic valid_r_rd; assign valid_r_rd = (pkt_data.op_0 == R_VAL) || (pkt_data.op_0 == R_SMALL_VAL);
    logic valid_r_rgb; assign valid_r_rgb = (pkt_data.op_2 == R_VAL) || (pkt_data.op_2 == R_SMALL_VAL);
    logic valid_g; assign valid_g = (pkt_data.op_1 == G_VAL) || (pkt_data.op_1 == G_SMALL_VAL);
    logic valid_b; assign valid_b = (pkt_data.op_0 == B_VAL) || (pkt_data.op_0 == B_SMALL_VAL);
    logic valid_l; assign valid_l = (pkt_data.op_0 == L_VAL) || (pkt_data.op_0 == L_SMALL_VAL);
    logic enforce_0; assign enforce_0 = (pkt_data.value_1[2] == '0) && (pkt_data.value_0[2] == '0);

    logic valid_wr_cmd; assign valid_wr_cmd = valid_w_wr && valid_v_wr_rd_op0 && valid_v_wr_rd_op1 && enforce_0 && pkt_valid;
    logic valid_rd_cmd; assign valid_rd_cmd = valid_r_rd && (pkt_data[PKT_WIDTH-1:SHORT_MSG_PAD_LSB] == '0) && pkt_valid;
    logic valid_rgb_cmd_temp; assign valid_rgb_cmd_temp = valid_r_rgb && valid_g && valid_b && pkt_valid;
    logic valid_led_cmd_temp; assign valid_led_cmd_temp = valid_l && (pkt_data[PKT_WIDTH-1:SHORT_MSG_PAD_LSB] == '0) && pkt_valid;

    logic is_value_led;
    assign is_value_led = (pkt_data.value_0[2] >= ASCII_ZERO) && (pkt_data.value_0[2] <= ASCII_NINE) &&
                        (pkt_data.value_0[1] >= ASCII_ZERO) && (pkt_data.value_0[1] <= ASCII_NINE) &&
                        (pkt_data.value_0[0] >= ASCII_ZERO) && (pkt_data.value_0[0] <= ASCII_NINE);

    logic is_value_rgb;
    assign is_value_rgb = (pkt_data.value_2[2] >= ASCII_ZERO) && (pkt_data.value_2[2] <= ASCII_NINE) &&
                        (pkt_data.value_2[1] >= ASCII_ZERO) && (pkt_data.value_2[1] <= ASCII_NINE) &&
                        (pkt_data.value_2[0] >= ASCII_ZERO) && (pkt_data.value_2[0] <= ASCII_NINE) &&
                        (pkt_data.value_1[2] >= ASCII_ZERO) && (pkt_data.value_1[2] <= ASCII_NINE) &&
                        (pkt_data.value_1[1] >= ASCII_ZERO) && (pkt_data.value_1[1] <= ASCII_NINE) &&
                        (pkt_data.value_1[0] >= ASCII_ZERO) && (pkt_data.value_1[0] <= ASCII_NINE) &&
                        is_value_led;


    logic [ASCII_TO_BIN_WIDTH-1:0] value_2, value_1, value_0;
    assign value_2 = pkt_data.value_2[2][3:0] * HUNDRED + pkt_data.value_2[1][3:0] * TEN + pkt_data.value_2[0][3:0];
    assign value_1 = pkt_data.value_1[2][3:0] * HUNDRED + pkt_data.value_1[1][3:0] * TEN + pkt_data.value_1[0][3:0];
    assign value_0 = pkt_data.value_0[2][3:0] * HUNDRED + pkt_data.value_0[1][3:0] * TEN + pkt_data.value_0[0][3:0];

    logic valid_led_cmd; assign valid_led_cmd = valid_led_cmd_temp && ((value_0 == LED16_VAL) || (value_0 == LED17_VAL)) && is_value_led;
    logic valid_rgb_cmd; assign valid_rgb_cmd = (value_0 <= MAX_PIXEL_VAL) &&
                                                (value_1 <= MAX_PIXEL_VAL) &&
                                                (value_2 <= MAX_PIXEL_VAL) &&
                                                valid_rgb_cmd_temp && is_value_rgb;
    assign msg_temp.msg_valid = valid_wr_cmd || valid_rd_cmd || valid_rgb_cmd || valid_led_cmd;

    always_comb begin : msg_type_dec
        msg_temp.msg_type = WRITE_CMD;
        unique case(1'b1)
            valid_wr_cmd: msg_temp.msg_type = WRITE_CMD;
            valid_rd_cmd: msg_temp.msg_type = READ_CMD;
            valid_rgb_cmd: msg_temp.msg_type = RGB_CMD;
            valid_led_cmd: msg_temp.msg_type = LED_CMD;
            default: msg_temp.msg_type = WRITE_CMD;
        endcase
    end

    logic led_sel;
    always_comb begin : msg_data_dec
        msg_temp.msg_data = '0;
        led_sel = '0;
        unique case(1'b1) 
            valid_wr_cmd: begin
                msg_temp.msg_data.addr = pkt_data.value_2;
                msg_temp.msg_data.data = {pkt_data.value_1[1:0], pkt_data.value_0[1:0]};
            end
            valid_rd_cmd: begin
                msg_temp.msg_data.addr = pkt_data.value_0;
                msg_temp.msg_data.data = '0;
            end
            valid_rgb_cmd: begin
                msg_temp.msg_data.addr = '0;
                msg_temp.msg_data.data = {value_2[DATA_WIDTH-1:0], value_1[DATA_WIDTH-1:0], value_0[DATA_WIDTH-1:0]};
            end
            valid_led_cmd: begin
                led_sel = (value_0 == LED16_VAL) ? 1'b0 : 1'b1;
                msg_temp.msg_data.addr = 0;
                msg_temp.msg_data.data = RGF_DATA_WIDTH'(led_sel);
            end
            default: {msg_temp.msg_data, led_sel} = '0;
        endcase
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) msg <= '0;
        else if (msg_temp.msg_valid) msg <= msg_temp;
        else msg.msg_valid <= '0;
    end

endmodule
