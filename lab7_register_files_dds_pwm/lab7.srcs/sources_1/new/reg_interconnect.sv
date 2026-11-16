import lab7_pkg::*;
import led_rgf_pkg::*;
import pwm_rgf_pkg::*;

    /*
        Messeges that can be recived:
            1. {WXXX,VXXX,VXXX} -> write message (need to take the address from W and write the value to that addr)
            2. {RXXX} -> Read command (returns the value in the address sent)
            3. {RXXX,GXXX,BXXX} -> sRGB value sent from pc to fgpa to se the current led value
            4. {LXXX} -> Led contorl to change leds 
        
        Messegas that the fpga sends to pc:
            1. {RXXX,VXXX,VXXX} -> reply from a read command 

        in total 4 different messages need to be decoded to other rgf files, 
        1 message to tx

        when write message wen = 1, addr = msg_addr[15:0], cs of the addr[23:16] gets 1, ren = 0 wdata gets msg_data
        when read command tx takes msg_addr, msg_data, wen = 0, ren = 1, addr[15:0] and cs addr[23:16]
        when rgb command wen = 1, addr = get the current led address from led_ctrl (see what the select is)
            wdata = msg data
        when Led command to send the correct data back when switching the led.
    */

module reg_interconnect (
    // need parser output
    input parsed_msg_t msg, // New struct to replace parser output (msg_valid, msg_type, msg_data)
    // TODO: ADD 3 more rdata inputs one for each rgf module
    input logic [RGF_DATA_WIDTH-1:0] led_rdata, pwm_rdata, cnt_rdata, sys_rdata,
    input led_ctrl_t led_ctrl, // Input from led_rgf (Needed for a rgb msg or a led msg)
    // Need to add inputs from 2 more reg files
    output logic wen, ren, 
    output logic [RGF_ADDR_WIDTH-1:0] addr, 
    output logic [RGF_DATA_WIDTH-1:0] wdata,
    output logic [RGF_NUM-1:0] cs_one_hot,
    output tx_mac_in_t tx_data,
    output logic msb_addr_err // Signal for sys_rgf.sys_status
);
    // 00 _ 00 00

    logic [RGF_ADDR_WIDTH-1:0] led_lsb_addr; assign led_lsb_addr = (led_ctrl.select == LED_CTRL_RESET_VAL[SELECT_STOP_BIT:SELECT_START_BIT]) ? LED16_VALUE_ADDR : LED17_VALUE_ADDR;

    logic [RGF_NUM-1:0] cs_temp; assign cs_temp = (msg.msg_valid) ? (1 << msg.msg_data.addr[2]) : '0;

    localparam LED_SELECT_FULL_ADDR = 24'h0;
    logic [ADDR_BYTES-2:0][DATA_WIDTH-1:0] lsb_addr_temp; assign lsb_addr_temp = msg.msg_data.addr[1:0];
    logic [1:0] led_sel;
    led_ctrl_t led_ctrl_temp;
    always_comb begin : msg_type_dec
        {wen, ren, addr, wdata, cs_one_hot, led_sel, led_ctrl_temp} = '0;
        if (msg.msg_valid) 
            unique case(msg.msg_type)
                WRITE_CMD: begin
                    wen = 1'b1;
                    ren = 1'b0;
                    addr = lsb_addr_temp;
                    wdata = msg.msg_data.data;
                    cs_one_hot = cs_temp;
                end
                READ_CMD: begin
                    wen = 1'b0;
                    ren = 1'b1;
                    addr = lsb_addr_temp;
                    wdata = '0;
                    cs_one_hot = cs_temp;
                end
                RGB_CMD: begin
                    wen = 1'b1;
                    ren = 1'b0;
                    addr = led_lsb_addr;
                    wdata = msg.msg_data.data;
                    cs_one_hot = (1 << LED_RGF_ADDR);
                end
                LED_CMD: begin
                    led_sel = (msg.msg_data.data == '0) ? LED16_SEL_VAL : LED17_SEL_VAL;
                    led_ctrl_temp = led_ctrl;
                    led_ctrl_temp.select = led_sel;
                    wen = 1'b1;
                    ren = 1'b0;
                    addr = LED_CTRL_ADDR;
                    wdata = RGF_DATA_WIDTH'(led_ctrl_temp); // can write {(led_ctrl >> 2), led_sel} 
                    cs_one_hot = (1 << LED_RGF_ADDR);
                end 
                default: {wen, ren, addr, wdata, cs_one_hot, led_sel, led_ctrl_temp} = '0;
            endcase
    end


    // TODO: ADD the tx outputs that depend on the rdata (need to pick correct one can prop use cs_one_hot)
    // tx_mac inputs: clk, reset_n, start, done, [2:0][SLOTS_WIDTH-1:0] pixel_data
    // tx mac now sends one message only: {RXXX,VXXX,VXXX}
    // so can change tx input type to be msg_data_t struct
    // use cs_one_hot to decode what rdata to pass to tx and the correct full address with it
    assign tx_data.start = ren && (cs_one_hot != '0);
    always_comb begin : tx_data_dec
        tx_data.msg = '0;
        if (tx_data.start) begin
            tx_data.msg.addr = msg.msg_data.addr;
            unique case(1'b1)
                cs_one_hot[0]: tx_data.msg.data = led_rdata;
                cs_one_hot[1]: tx_data.msg.data = pwm_rdata;
                cs_one_hot[2]: tx_data.msg.data = cnt_rdata;
                cs_one_hot[3]: tx_data.msg.data = sys_rdata;
                default: tx_data.msg.data = '0;
            endcase
        end
    end

    assign msb_addr_err = (msg.msg_data.addr[2] > RGF_NUM -1) && msg.msg_valid && ((msg.msg_type == WRITE_CMD) || (msg.msg_type == READ_CMD)); 

endmodule
