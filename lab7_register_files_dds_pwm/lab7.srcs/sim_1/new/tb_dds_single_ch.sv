import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;

module tb_dds_single_ch;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic cnt_wrap = '0;
    pwm_ctrl_t pwm_ch_ctrl = '0;
    logic pattern_change = '0;
    logic [GAMMA_WIDTH-1:0] dds_ch_val;

    dds_single_ch dut(
        .clk(clk),
        .reset_n(reset_n),
        .cnt_wrap(cnt_wrap),
        .pwm_ch_ctrl(pwm_ch_ctrl),
        .pattern_change(pattern_change),
        .dds_ch_val(dds_ch_val)
    );

    typedef enum logic [1:0] {IDLE, STEP, LOAD, LOAD_STEP} op_t; //cnt_wrap, pattern_change
    logic [16:0] exp_acc;

    // round(1023 · (1 + sin(2π·i/512 − π/2)) / 2)), for all 512 entries
    function automatic logic [9:0] calc_table_val(input logic[8:0] i);
        localparam real PI = 3.14159265358979323846;
        real angle;
        real exact_val;
        int rounded_val;

        angle = (2.0 * PI * real'(i) / 512.0) - (PI / 2.0);
        exact_val = 1023.0 * ((1.0 + $sin(angle)) / 2.0);
        rounded_val = int'(exact_val);

        return 10'(rounded_val);
    endfunction

    function automatic logic [GAMMA_WIDTH-1:0] calc_exp_val(input logic[16:0] acc);
        int temp;
        temp = calc_table_val(acc[16:8]) * (2**int'(pwm_ch_ctrl.mag));
        return (temp > 1023) ? GAMMA_WIDTH'(1023) : GAMMA_WIDTH'(temp);
    endfunction

    task reset_dut();
        reset_n = '0;
        cnt_wrap = '0;
        pwm_ch_ctrl = '0;
        pattern_change = '0;
        exp_acc = '0;
        repeat(3) @(posedge clk);
        assert(dds_ch_val === '0) else $error("Time: %0t | ERROR: Invalid reset value | dds_ch_val | actual=%0h | exp=%0h", $time, dds_ch_val, '0);
        reset_n <= '1;
    endtask

    task drive_pwm_ctrl(input pwm_ctrl_t ctrl);
        @(posedge clk);
        pwm_ch_ctrl <= ctrl;
        @(posedge clk);
    endtask

    task inc_exp_acc(input op_t op);
        unique case(op)
            IDLE: exp_acc = exp_acc;
            STEP: exp_acc = exp_acc + pwm_ch_ctrl.freq;
            LOAD: exp_acc = {pwm_ch_ctrl.phase, 8'h0};
            LOAD_STEP: exp_acc = {pwm_ch_ctrl.phase, 8'h0};
            default: exp_acc = exp_acc;
        endcase
    endtask

    task drive(input op_t op);
        logic [GAMMA_WIDTH-1:0] exp_dds_val;
        @(posedge clk);
        unique case(op)
            IDLE: begin cnt_wrap <= '0; pattern_change <= '0; end
            STEP: begin cnt_wrap <= '1; pattern_change <= '0; end
            LOAD: begin cnt_wrap <= '0; pattern_change <= '1; end
            LOAD_STEP: begin cnt_wrap <= '1; pattern_change <= '1; end
            default: begin cnt_wrap <= '0; pattern_change <= '0; end
        endcase
        @(posedge clk); // loads into dut
        inc_exp_acc(op);
        {cnt_wrap, pattern_change} <= '0;
        @(posedge clk); 
        //can check
        exp_dds_val = calc_exp_val(exp_acc);
        assert(exp_acc === dut.acc) else $error("Time: %0t | ERROR: Invalid dut.acc value per operation | actual=%d | expected=%d | operation=%s", $time, dut.acc, exp_acc, op.name());
        assert(dds_ch_val === exp_dds_val) else $error("Time: %0t | ERROR: Invalid dds_ch_val value | actual=%d | expetcted=%d | operation=%s", $time, dds_ch_val, exp_dds_val, op.name());
    endtask;

    op_t op;
    initial begin
        reset_dut();
        drive_pwm_ctrl('{freq: 256, mag:2, phase:256});
        op = op.first();
        for(int i = 0; i < op.num(); i++) begin
            drive(op);
            op = op.next();
        end

        drive_pwm_ctrl('{freq:2, mag:0, phase:0});
        drive(LOAD);
        repeat(5) drive(STEP);

        drive_pwm_ctrl('{freq:'0, mag: '0, phase: 510});
        drive(LOAD);
        repeat(5) drive(STEP);

        drive_pwm_ctrl('{freq:128, mag:'0, phase:0});
        drive(LOAD);
        repeat(2) drive(STEP);

        drive_pwm_ctrl('{freq: 5000, mag: '0, phase:0});
        drive(LOAD); drive(STEP);


        reset_dut();


        $finish;
    end


    property p_acc_reset;
        @(posedge clk)
        (!reset_n) |=> (dut.acc === '0);
    endproperty
    assert property(p_acc_reset) else $error("Time: %0t | ERROR: DUT acc bad reset value | atual=%0d | expedted=%0d", $time, dut.acc, '0);

    property p_acc_hold;
        @(posedge clk)
        disable iff(!reset_n)
        (!cnt_wrap && !pattern_change) |=> ($stable(dut.acc));
    endproperty
    assert property(p_acc_hold) else $error("Time: %0t | ERROR: DUT acc changing at incorrect times", $time);

    
    property p_acc_step;
        @(posedge clk)
        disable iff(!reset_n)
        (cnt_wrap & !pattern_change) |=> (dut.acc === ($past(dut.acc) + $past(17'(pwm_ch_ctrl.freq))));
    endproperty
    assert property(p_acc_step) else $error("Time: %0t | ERROR: Invalid acc step", $time);

    property p_acc_phase_load;
        @(posedge clk)
        disable iff(!reset_n)
        (pattern_change) |=> (dut.acc === {$past(pwm_ch_ctrl.phase), 8'h0});
    endproperty
    assert property(p_acc_phase_load) else $error("Time: %0t | ERROR: Invalid acc patern_change load", $time);



endmodule
