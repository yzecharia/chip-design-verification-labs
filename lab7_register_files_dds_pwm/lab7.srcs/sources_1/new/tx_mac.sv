import lab7_pkg::*;
`include "lab7_definitions.svh"

module tx_mac (
    input logic clk, reset_n,
    input logic done,
    input tx_mac_in_t tx_in,
    output logic [DATA_WIDTH-1:0] drive_data,
    output logic tx_start,       
    output logic tx_msg_sent                         
);

    /*
        tx_mac now gets input from reg_interconnect module
        new input tx_mac_in_t include start signal and addr and data)
        in total tx_in.msg.addr = [DATA_WIDTH-1:0][DATA_WIDTH-1:0][DATA_WIDTH-1:0]
                tx_in.msg.data = [DATA_WIDTH-1:0][DATA_WIDTH-1:0][DATA_WIDTH-1:0][DATA_WIDTH-1:0][DATA_WIDTH-1:0][DATA_WIDTH-1:0]

            so in total 6 bytes to order in a 
            { R addr[2] addr[1] addr[0] , V  8'h00 data[3] data[2]   , V 8'h00 data[1] data[0] }
            0 1   2       3.      4.    5 6.  7.      8.      9.    10 11 12.    13.     14.    15
    */


    localparam GROUP_NUM = 4;
    localparam GROUP_WIDTH = $clog2(GROUP_NUM);

    localparam ELEMENT_NUM = 5;
    localparam ELEMENT_WIDTH = $clog2(ELEMENT_NUM);

    tx_state_t state, next;

    logic [GROUP_WIDTH-1:0] group_cnt;
    logic [ELEMENT_WIDTH-1:0] element_cnt;
    logic last_group; assign last_group = (group_cnt == GROUP_NUM-1);
    logic last_element; assign last_element = (element_cnt == ELEMENT_NUM-1);
    logic msg_close; assign msg_close = (element_cnt == '0) & last_group;
    logic sent_all; assign sent_all = (state == TX_TRANSMIT) & msg_close & done;

    assign tx_msg_sent = sent_all;

    // element counter
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) element_cnt <= '0;
        else if ((last_element & done & (state == TX_TRANSMIT)) | ((state == TX_IDLE) & tx_in.start)) element_cnt <= '0;
        else if ((state == TX_TRANSMIT) & done & !sent_all) element_cnt <= element_cnt + 1;
    end

    // group counter
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) group_cnt <= '0;
        else if (((state == TX_IDLE) & tx_in.start) | sent_all) group_cnt <= '0;
        else if ((state == TX_TRANSMIT) & done & last_element) group_cnt <= group_cnt + 1;
    end

    // state register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= TX_IDLE;
        else state <= next;
    end

    // msg_reg
    msg_data_t msg_temp;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) msg_temp <= '0;
        else if ((state == TX_IDLE) && tx_in.start) msg_temp <= tx_in.msg;
    end

    // next state
    always_comb begin
        next = state;
        unique case(state)
            TX_IDLE: next = (tx_in.start) ? TX_TRANSMIT : TX_IDLE;
            TX_TRANSMIT: next = (!sent_all) ? TX_TRANSMIT : TX_IDLE;
            default: next = TX_IDLE;                                      
        endcase
    end

    // start pulse to tx_phy, one per byte
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) tx_start <= '0;
        else tx_start <= ((state == TX_IDLE) & tx_in.start) | ((state == TX_TRANSMIT) & done & !sent_all);
    end

    logic [DATA_WIDTH-1:0] group_opener, opcode;
    logic [ADDR_BYTES-1:0][DATA_WIDTH-1:0] group_val;
    always_comb begin
        unique case(group_cnt)
            2'd0: begin
                group_opener = MSG_START_VAL;                                  
                opcode = R_VAL;
                group_val = msg_temp.addr;                                      
            end
            2'd1: begin
                group_opener = COMMA_VAL;
                opcode = V_VAL;
                group_val = {8'h00, msg_temp.data[3], msg_temp.data[2]};
            end
            2'd2: begin
                group_opener = COMMA_VAL;
                opcode = V_VAL;
                group_val = {8'h00, msg_temp.data[1], msg_temp.data[0]};
            end
            2'd3: begin
                group_opener = MSG_CLOSE_VAL;
                {opcode, group_val} = '0;
            end 
            default: {group_opener, opcode, group_val} = '0;
        endcase
    end

    always_comb begin
        unique case(element_cnt)
            3'd0: drive_data = group_opener;
            3'd1: drive_data = opcode;
            3'd2, 3'd3, 3'd4: drive_data = group_val[(ELEMENT_NUM-1) - element_cnt];
            default: drive_data = '0;
        endcase
    end

endmodule
