import lab7_pkg::*;
import pwm_rgf_pkg::*;

module pwm_rgf (
    input logic clk, reset_n,
    input logic cs, wen, ren,
    input logic [RGF_ADDR_WIDTH-1:0] addr,
    input logic [RGF_DATA_WIDTH-1:0] wdata,
    output logic [RGF_DATA_WIDTH-1:0] rdata,
    output pwm_rgf_msg_t pwm_rgf_msg
);

    pwm_status_t pwm_status;

    logic cfg_sel, red_ctrl_sel, green_ctrl_sel, blue_ctrl_sel, status_sel;
    logic addr_err_comb;

    always_comb begin : RW_addr_dec
        cfg_sel = '0;
        red_ctrl_sel = '0;
        green_ctrl_sel = '0;
        blue_ctrl_sel = '0;
        status_sel = '0;
        addr_err_comb = '0;
        unique case(addr) 
            PWM_CFG_ADDR: cfg_sel = 1'b1;
            RED_PWM_CTRL_ADDR: red_ctrl_sel = 1'b1;
            GREEN_PWM_CTRL_ADDR: green_ctrl_sel = 1'b1;
            BLUE_PWM_CTRL_ADDR: blue_ctrl_sel = 1'b1;
            PWM_STATUS_ADDR: status_sel = 1'b1;
            default: addr_err_comb = 1'b1;
        endcase
    end

    logic sweep_err; assign sweep_err = cs && wen && (wdata[SWEEP_TIME_STOP_BIT: SWEEP_TIME_START_BIT] == '0);
    logic time_err; assign time_err = cs && wen && (wdata[TIME_SLOTS_STOP_BIT: TIME_SLOTS_START_BIT] == '0);
    always_ff @(posedge clk or negedge reset_n) begin : RW_data_dec
        if (!reset_n) begin
            pwm_rgf_msg.pwm_cfg <= PWM_CFG_RESET_VAL[PWM_CFG_STOP_BIT: PWM_CFG_START_BIT];
            pwm_rgf_msg.red_ctrl <= RED_PWM_CTRL_RESET_VAL[RED_PWM_CTRL_STOP_BIT: RED_PWM_CTRL_START_BIT];
            pwm_rgf_msg.green_ctrl <= GREEN_PWM_CTRL_RESET_VAL[GREEN_PWM_CTRL_STOP_BIT: GREEN_PWM_CTRL_START_BIT];
            pwm_rgf_msg.blue_ctrl <= BLUE_PWM_CTRL_RESET_VAL[BLUE_PWM_CTRL_STOP_BIT: BLUE_PWM_CTRL_START_BIT];
        end else if (cs & wen) begin
            unique case (1'b1)
                cfg_sel: if (!sweep_err & !time_err) pwm_rgf_msg.pwm_cfg <= wdata[PWM_CFG_STOP_BIT: PWM_CFG_START_BIT];
                red_ctrl_sel: pwm_rgf_msg.red_ctrl <= wdata[RED_PWM_CTRL_STOP_BIT: RED_PWM_CTRL_START_BIT];
                green_ctrl_sel: pwm_rgf_msg.green_ctrl <= wdata[GREEN_PWM_CTRL_STOP_BIT: GREEN_PWM_CTRL_START_BIT];
                blue_ctrl_sel: pwm_rgf_msg.blue_ctrl <= wdata[BLUE_PWM_CTRL_STOP_BIT: BLUE_PWM_CTRL_START_BIT];
                default: ;
            endcase
        end
    end

    logic addr_err; assign addr_err = cs && (wen || ren) && addr_err_comb;
    logic clr_addr_err; assign clr_addr_err = cs && ren && status_sel;
    always_ff @(posedge clk or negedge reset_n) begin : R0C_pwm_status
        if (!reset_n) pwm_status <= PWM_STATUS_RESET_VAL[PWM_STATUS_STOP_BIT: PWM_STATUS_START_BIT];
        else if (addr_err) pwm_status <= 1'b1;
        else if (clr_addr_err) pwm_status <= 1'b0; 
    end
    
    always_comb begin : RW_rd_decoder
        rdata = '0;
        if (cs & !wen) begin
            unique case (1'b1) 
                cfg_sel: rdata = pwm_rgf_msg.pwm_cfg;
                red_ctrl_sel: rdata = pwm_rgf_msg.red_ctrl;
                green_ctrl_sel: rdata = pwm_rgf_msg.green_ctrl;
                blue_ctrl_sel: rdata = pwm_rgf_msg.blue_ctrl;
                status_sel: rdata = pwm_status;
                default: rdata = '0;
            endcase
        end
    end

endmodule
