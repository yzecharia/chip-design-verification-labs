import lab7_pkg::*;
import pwm_rgf_pkg::*;

module tb_pwm_rgf;

    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n;
    logic cs, wen, ren;
    logic [RGF_ADDR_WIDTH-1:0] addr;
    logic [RGF_DATA_WIDTH-1:0] wdata, rdata;
    pwm_rgf_msg_t pwm_rgf_msg;

    pwm_rgf pwm_rgf_i (
        .clk(clk),
        .reset_n(reset_n),
        .cs(cs),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .pwm_rgf_msg(pwm_rgf_msg)
    );

    typedef struct packed {
        logic cs;
        logic wen;
        logic [RGF_ADDR_WIDTH-1:0] addr;
        logic [RGF_DATA_WIDTH-1:0] wdata;
    } write_msg_t;
    typedef struct packed {
        logic cs;
        logic ren;
        logic [RGF_ADDR_WIDTH-1:0] addr;
    } read_msg_t;

    pwm_rgf_msg_t exp_pwm_rgf_msg;
    pwm_rgf_msg_t prev_msg;
    pwm_status_t prev_status;

    task reset_dut();
        reset_n = '0;
        cs = '0; wen = '0; ren = '0; addr = '0; wdata = '0;
        repeat (3) @(posedge clk);
        assert(rdata === '0)
            else $error("Time: %0t | ERROR: Invalid rdata reset value", $time);
        assert(pwm_rgf_msg.pwm_cfg === {16'd1024, 16'd1})
            else $error("Time: %0t | ERROR: Invalid pwm_cfg reset values", $time);
        assert(pwm_rgf_msg.red_ctrl === {13'd10, 2'd0, 9'd0})
            else $error("Time: %0t | ERROR: Invalid red_ctrl reset values", $time);
        assert(pwm_rgf_msg.green_ctrl === {13'd10, 2'd0, 9'd0})
            else $error("Time: %0t | ERROR: Invalid green_ctrl reset values", $time);
        assert(pwm_rgf_msg.blue_ctrl === {13'd10, 2'd0, 9'd0})
            else $error("Time: %0t | ERROR: Invalid blue_ctrl reset values", $time);
        assert(pwm_rgf_i.pwm_status === 1'b0)
            else $error("Time: %0t | ERROR: Invalid pwm_status reset value", $time);
        reset_n <= '1;
    endtask

    task drive_write_cmd(input write_msg_t msg);
        ren <= '0;
        @(posedge clk);
        exp_pwm_rgf_msg = pwm_rgf_msg;
        {cs, wen, addr, wdata} <= msg; @(posedge clk); // msg load
        {cs, wen} <= '0; @(posedge clk); 
        // can check output
        check_pwm_rgf_msg(msg, exp_pwm_rgf_msg);
    endtask 

    task check_pwm_rgf_msg(input write_msg_t msg, input pwm_rgf_msg_t exp);
        bit sweep_err;
        bit time_err;
        sweep_err = (msg.wdata[SWEEP_TIME_STOP_BIT: SWEEP_TIME_START_BIT] == '0);
        time_err = (msg.wdata[TIME_SLOTS_STOP_BIT: TIME_SLOTS_START_BIT] == '0);
        if (msg.cs && msg.wen)
            case (msg.addr)
                PWM_CFG_ADDR: if (!sweep_err && !time_err) exp.pwm_cfg = msg.wdata[PWM_CFG_STOP_BIT: PWM_CFG_START_BIT];
                RED_PWM_CTRL_ADDR: exp.red_ctrl = msg.wdata[RED_PWM_CTRL_STOP_BIT: RED_PWM_CTRL_START_BIT];
                GREEN_PWM_CTRL_ADDR: exp.green_ctrl = msg.wdata[GREEN_PWM_CTRL_STOP_BIT: GREEN_PWM_CTRL_START_BIT];
                BLUE_PWM_CTRL_ADDR: exp.blue_ctrl = msg.wdata[BLUE_PWM_CTRL_STOP_BIT: BLUE_PWM_CTRL_START_BIT];
                default: ;
            endcase
        assert(exp.pwm_cfg === pwm_rgf_msg.pwm_cfg) else $error("Time: %0t | ERROR: Write to pwm_cfg not working", $time);
        assert(exp.red_ctrl === pwm_rgf_msg.red_ctrl) else $error("Time: %0t | ERROR: Write to red_ctrl not working", $time);
        assert(exp.green_ctrl === pwm_rgf_msg.green_ctrl) else $error("Time: %0t | ERROR: Write to green_ctrl not working", $time);
        assert(exp.blue_ctrl === pwm_rgf_msg.blue_ctrl) else $error("Time: %0t | ERROR: Write to blue_ctrl not working", $time);
    endtask

    task drive_read_cmd(input read_msg_t msg);
        wen <= '0;
        @(posedge clk);
        prev_msg = pwm_rgf_msg;
        prev_status = pwm_rgf_i.pwm_status;
        {cs, ren, addr} <= msg; @(posedge clk);
        // check here (Combinational)
        check_read(msg, prev_msg, prev_status);
        {cs, ren} <= '0; @(posedge clk);
        assert(pwm_rgf_msg === prev_msg) else $error("Time: %0t | ERROR: Read changed a register at address: %h", $time, msg.addr);
    endtask

    task check_read(input read_msg_t msg, input pwm_rgf_msg_t prev, input pwm_status_t prev_stat);
        logic [RGF_DATA_WIDTH-1:0] exp;
        exp = '0;
        if (msg.ren && msg.cs)
            case(msg.addr)
                PWM_CFG_ADDR: exp = prev.pwm_cfg;
                RED_PWM_CTRL_ADDR: exp = prev.red_ctrl;
                GREEN_PWM_CTRL_ADDR: exp = prev.green_ctrl;
                BLUE_PWM_CTRL_ADDR: exp = prev.blue_ctrl;
                PWM_STATUS_ADDR: exp = prev_stat;
                default: ;
            endcase
        assert(rdata === exp) else $error("Time: %0t | ERROR: Read not working at address: %h", $time, msg.addr);
    endtask

    logic addr_exists; assign addr_exists = (addr == PWM_CFG_ADDR) || (addr == RED_PWM_CTRL_ADDR) || (addr == GREEN_PWM_CTRL_ADDR) || (addr == BLUE_PWM_CTRL_ADDR) || (addr == PWM_STATUS_ADDR);
    logic bad_access; assign bad_access = cs && (wen || ren) && !addr_exists;
    logic status_read; assign status_read = cs && ren && (addr == PWM_STATUS_ADDR);

    property p_pwm_status_rise_condition;
        @(posedge clk)
        disable iff(!reset_n)
        bad_access |=> pwm_rgf_i.pwm_status.addr_err;
    endproperty

    property p_pwm_status_fall_condition;
        @(posedge clk)
        disable iff(!reset_n)
        status_read |=> !pwm_rgf_i.pwm_status.addr_err;
    endproperty

    assert property(p_pwm_status_rise_condition) else $error("Time: %0t | ERROR: pwm_status did not rise on invalid address", $time);
    assert property(p_pwm_status_fall_condition) else $error("Time: %0t | ERROR: pwm_status did not clear after read", $time);


    initial begin
        reset_dut();

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: PWM_CFG_ADDR, wdata: 32'h02000002});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: PWM_CFG_ADDR});
        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: PWM_CFG_ADDR, wdata: 32'h00000005});
        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: PWM_CFG_ADDR, wdata: 32'h01000000});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: PWM_CFG_ADDR});

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: RED_PWM_CTRL_ADDR, wdata: 32'hFF123456});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: RED_PWM_CTRL_ADDR});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: GREEN_PWM_CTRL_ADDR});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: BLUE_PWM_CTRL_ADDR});

        drive_write_cmd('{cs: 1'b0, wen: 1'b1, addr: GREEN_PWM_CTRL_ADDR, wdata: 32'h00ABCDEF});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: GREEN_PWM_CTRL_ADDR});

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: 16'h0030, wdata: 32'h12345678});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: PWM_STATUS_ADDR});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: PWM_STATUS_ADDR});

        reset_dut();

        repeat (2) @(posedge clk);
        $finish;
    end

endmodule
