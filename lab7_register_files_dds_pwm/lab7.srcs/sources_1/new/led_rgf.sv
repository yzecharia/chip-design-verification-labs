import lab7_pkg::*;
import led_rgf_pkg::*;
module led_rgf (
    input logic clk, reset_n,
    input selector_data_t select_in,
    input logic cs, wen, ren,
    input logic [RGF_ADDR_WIDTH-1:0] addr,
    input logic [RGF_DATA_WIDTH-1:0] wdata,
    output logic [RGF_DATA_WIDTH-1:0] rdata,
    output led_rgf_msg_t led_rgf_msg,
    output logic pc_led_update,
    output logic pattern_change
);

    led_status_t led_status;

    logic addr_err_comb;
    logic ctrl_sel, pattern_sel, led16_val_sel, led17_val_sel, status_sel;

    always_comb begin : reg_addr_dec
        ctrl_sel = '0;
        pattern_sel = '0;
        led16_val_sel = '0;
        led17_val_sel = '0;
        status_sel = '0;
        addr_err_comb = '0;
        unique case(addr)
            LED_CTRL_ADDR: ctrl_sel = '1;
            LED_PATTERN_ADDR: pattern_sel = '1;
            LED16_VALUE_ADDR: led16_val_sel = '1;
            LED17_VALUE_ADDR: led17_val_sel = '1;
            LED_STATUS_ADDR: status_sel = '1;
            default: addr_err_comb = '1;
        endcase
    end

    logic ctrl_sel_err; assign ctrl_sel_err = cs && wen && ctrl_sel && ((wdata[SELECT_STOP_BIT:SELECT_START_BIT] == 2'b00) || (wdata[SELECT_STOP_BIT:SELECT_START_BIT] == 2'b11));
    logic pattern_err; assign pattern_err = cs && wen && pattern_sel && ((wdata[LED_PATTERN_STOP_BIT: LED_PATTERN_START_BIT] == 2'b11));
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            led_rgf_msg.led_ctrl <= LED_CTRL_RESET_VAL[LED_CTRL_STOP_BIT:LED_CTRL_START_BIT];
            led_rgf_msg.led_pattern <= LED_PATTERN_RESET_VAL[LED_PATTERN_STOP_BIT:LED_PATTERN_START_BIT];
            led_rgf_msg.led16_value <= LED16_VALUE_RESET_VAL[LED16_VALUE_STOP_BIT:LED16_VALUE_START_BIT];
            led_rgf_msg.led17_value <= LED17_VALUE_RESET_VAL[LED17_VALUE_STOP_BIT: LED17_VALUE_START_BIT];
        end else if (select_in.btnc) begin
                led_rgf_msg.led_ctrl.select <= select_in.display_led ? 2'b10 : 2'b01;
                if (select_in.display_led) led_rgf_msg.led17_value <= select_in.led_value;
                else led_rgf_msg.led16_value <= select_in.led_value;
        end else if (cs & wen) begin
            unique case (1'b1) 
                ctrl_sel: if (!ctrl_sel_err) led_rgf_msg.led_ctrl <= wdata[LED_CTRL_STOP_BIT:LED_CTRL_START_BIT];
                pattern_sel: if (!pattern_err) led_rgf_msg.led_pattern <= wdata[LED_PATTERN_STOP_BIT:LED_PATTERN_START_BIT];
                led16_val_sel: led_rgf_msg.led16_value <= wdata[LED16_VALUE_STOP_BIT: LED16_VALUE_START_BIT];
                led17_val_sel: led_rgf_msg.led17_value <= wdata[LED17_VALUE_STOP_BIT: LED17_VALUE_START_BIT];
                default: ;
            endcase
        end 
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) pc_led_update <= '0;
        else if (cs & wen & (ctrl_sel | led16_val_sel | led17_val_sel) & !select_in.btnc & !ctrl_sel_err) pc_led_update <= '1;
        else pc_led_update <= '0;
    end

    logic addr_err; assign addr_err = cs && (wen || ren) && addr_err_comb; //set the error is chipselect and we are writing or reading and their is an addres error
    logic clr_addr_err; assign clr_addr_err = cs && ren && status_sel; // led_status is R0C, need to clear it after read, so if chipselect and read and we read the status can clear it

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) led_status <= LED_STATUS_RESET_VAL[LED_STATUS_STOP_BIT: LED_STATUS_START_BIT];
        else if (addr_err) led_status <= 1'b1;
        else if (clr_addr_err) led_status <= '0;
    end

    always_comb begin
        rdata = '0;
        if (cs & ren) begin
            unique case(1'b1) 
                ctrl_sel: rdata = led_rgf_msg.led_ctrl;
                pattern_sel: rdata = led_rgf_msg.led_pattern;
                led16_val_sel: rdata = led_rgf_msg.led16_value;
                led17_val_sel: rdata = led_rgf_msg.led17_value;
                status_sel: rdata = led_status;
                default: rdata = '0;
            endcase
        end
    end     

    // pattern change pulse for dds
    logic [1:0] pattern_prev;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) pattern_prev <= '0;
        else pattern_prev <= led_rgf_msg.led_pattern;
    end
    assign pattern_change = |(pattern_prev ^ led_rgf_msg.led_pattern);

endmodule
