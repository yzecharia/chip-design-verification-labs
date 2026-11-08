import lab6_pkg::*;
`include "lab6_definitions.svh"

module tx_mac #(
    parameter SLOTS = `SLOTS,           
    localparam SLOTS_WIDTH = $clog2(SLOTS)
) (
    input logic clk, reset_n,
    input logic start, done,
    input logic [2:0][SLOTS_WIDTH-1:0] pixel_data, // [2] = R, [1] = G, [0] = B, same order as cie_scaling
    output logic [DATA_WIDTH-1:0] drive_data,
    output logic tx_start                                 
);
    localparam GROUP_NUM = 4;
    localparam GROUP_WIDTH = $clog2(GROUP_NUM);

    localparam ELEMENT_NUM = 6;
    localparam ELEMENT_WIDTH = $clog2(ELEMENT_NUM);

    tx_state_t state, next;

    logic [GROUP_WIDTH-1:0] group_cnt;
    logic [ELEMENT_WIDTH-1:0] element_cnt;
    logic last_group; assign last_group = (group_cnt == GROUP_NUM-1);
    logic last_element; assign last_element = (element_cnt == ELEMENT_NUM-1);
    logic msg_close; assign msg_close = (element_cnt == '0) & last_group;
    logic sent_all; assign sent_all = (state == TX_TRANSMIT) & msg_close & done;

    logic start_mid_trans;

    // element counter
    always_ff @(posedge clk) begin
        if (!reset_n) element_cnt <= '0;
        else if ((last_element & done & (state == TX_TRANSMIT)) | ((state == TX_IDLE) & start) | (sent_all & start_mid_trans)) element_cnt <= '0;
        else if ((state == TX_TRANSMIT) & done & !sent_all) element_cnt <= element_cnt + 1;
    end

    // group counter
    always_ff @(posedge clk) begin
        if (!reset_n) group_cnt <= '0;
        else if (((state == TX_IDLE) & start) | sent_all) group_cnt <= '0;
        else if ((state == TX_TRANSMIT) & done & last_element) group_cnt <= group_cnt + 1;
    end

    // pending flag
    always_ff @(posedge clk) begin
        if (!reset_n) start_mid_trans <= '0;
        else if (((state == TX_IDLE) & start) | ((state == TX_TRANSMIT) & sent_all)) start_mid_trans <= '0;
        else if ((state == TX_TRANSMIT) & start) start_mid_trans <= '1;
    end

    // state register
    always_ff @(posedge clk) begin
        if (!reset_n) state <= TX_IDLE;
        else state <= next;
    end

    // next state
    always_comb begin
        next = state;
        unique case(state)
            TX_IDLE: next = (start) ? TX_TRANSMIT : TX_IDLE;
            TX_TRANSMIT: next = (!sent_all) ? TX_TRANSMIT : ((start_mid_trans) ? TX_TRANSMIT : TX_IDLE);
            default: next = TX_IDLE;                                      
        endcase
    end

    // start pulse to tx_phy, one per byte
    always_ff @(posedge clk) begin
        if (!reset_n) tx_start <= '0;
        else tx_start <= ((state == TX_IDLE) & start) | (sent_all & start_mid_trans) | ((state == TX_TRANSMIT) & done & !sent_all);
    end

    logic [DATA_WIDTH-1:0] group_opener, opcode;
    logic [SLOTS_WIDTH-1:0] group_val;
    always_comb begin
        unique case(group_cnt)
            2'd0: begin
                group_opener = MSG_START_VAL;                                  
                opcode = R_VAL;
                group_val = pixel_data[2];                                      
            end
            2'd1: begin
                group_opener = COMMA_VAL;
                opcode = G_VAL;
                group_val = pixel_data[1];
            end
            2'd2: begin
                group_opener = COMMA_VAL;
                opcode = B_VAL;
                group_val = pixel_data[0];
            end
            2'd3: begin
                group_opener = MSG_CLOSE_VAL;
                {opcode, group_val} = '0;
            end 
            default: {group_opener, opcode, group_val} = '0;
        endcase
    end

    // bcd conversion starts with the opener byte of each group; the digits are needed 2 bytes later
    logic bcd_start; assign bcd_start = tx_start & (element_cnt == 3'd0);
    logic bcd_done;
    logic [NUM_DIGITS-1:0][DIG_IN_WIDTH-1:0] bcd_val;
    binary_2_bcd #(.SLOTS(SLOTS)) bin2bcd (
        .clk(clk),
        .reset_n(reset_n),
        .start(bcd_start),
        .bin_in(group_val),
        .bcd_out(bcd_val),
        .done(bcd_done)
    );

    always_comb begin
        unique case(element_cnt)
            3'd0: drive_data = group_opener;
            3'd1: drive_data = opcode;
            3'd2, 3'd3, 3'd4, 3'd5: drive_data = {4'h3, bcd_val[(ELEMENT_NUM-1) - element_cnt]};
            default: drive_data = '0;
        endcase
    end

endmodule
