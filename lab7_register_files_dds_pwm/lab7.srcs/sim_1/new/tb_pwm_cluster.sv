import lab7_pkg::*;
import pwm_rgf_pkg::*;

module tb_pwm_cluster;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    pwm_cfg_t pwm_cfg = '0;
    scaled_val_t [RGB_LED_NUM-1:0] scaled_vals = '0;
    logic [CH_NUM-1:0] pwm_signals_16, pwm_signals_17;
    logic wrap_cnt;

    pwm_cluster dut (
        .clk(clk),
        .reset_n(reset_n),
        .pwm_cfg(pwm_cfg),
        .scaled_vals(scaled_vals),
        .pwm_signals_16(pwm_signals_16),
        .pwm_signals_17(pwm_signals_17),
        .wrap_cnt(wrap_cnt)
    );

    int errors = 0;

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert ((pwm_signals_16 === '0) && (pwm_signals_17 === '0)) else begin
            $error("pwm_signals_16 = %b, pwm_signals_17 = %b after reset", pwm_signals_16, pwm_signals_17);
            errors++;
        end
        reset_n = '1;
    endtask

    function int period(input pwm_cfg_t cfg);
        return cfg.sweep_time * cfg.time_slots;
    endfunction

    // counts the high clocks on all six pins and the wrap_cnt pulses during one full period
    task measure(output int ones16 [CH_NUM-1:0], output int ones17 [CH_NUM-1:0], output int wraps);
        for (int i = 0; i < CH_NUM; i++) begin
            ones16[i] = 0;
            ones17[i] = 0;
        end
        wraps = 0;
        for (int c = 0; c < period(pwm_cfg); c++) begin
            for (int i = 0; i < CH_NUM; i++) begin
                ones16[i] += pwm_signals_16[i];
                ones17[i] += pwm_signals_17[i];
            end
            wraps += wrap_cnt;
            #(CLK_PERIOD);
        end
    endtask

    // every pin is high for its value * time_slots clocks
    task check_leds(input scaled_val_t v16, v17, input string name);
        int ones16 [CH_NUM-1:0], ones17 [CH_NUM-1:0], wraps;
        $display("Time: %0t | TASK: LED16 = %0d %0d %0d, LED17 = %0d %0d %0d", $time, v16[2], v16[1], v16[0], v17[2], v17[1], v17[0]);
        scaled_vals = {v17, v16};
        #(CLK_PERIOD * 3 * period(pwm_cfg)); // the new values are taken at the end of a period
        measure(ones16, ones17, wraps);
        for (int i = 0; i < CH_NUM; i++) begin
            assert ((ones16[i] == v16[i] * pwm_cfg.time_slots) && (ones17[i] == v17[i] * pwm_cfg.time_slots))
            else begin
                $error("%s: channel %0d, LED16 high %0d (expected %0d), LED17 high %0d (expected %0d)", name, i,
                       ones16[i], v16[i] * pwm_cfg.time_slots, ones17[i], v17[i] * pwm_cfg.time_slots);
                errors++;
            end
        end
        assert (wraps == 1) else begin
            $error("%s: wrap_cnt pulses = %0d in one period, expected 1", name, wraps);
            errors++;
        end
        $display("Time: %0t | DONE: %s", $time, name);
    endtask

    initial begin
        pwm_cfg.sweep_time = 10;
        pwm_cfg.time_slots = 4;
        reset_dut();

        // Scenario 1: different duties on all six channels, each led gets its own values
        $display("Time: %0t | Scenario 1 - both leds", $time);
        check_leds({16'd8, 16'd5, 16'd1}, {16'd2, 16'd10, 16'd4}, "both leds");

        // Scenario 2: LED16 off and LED17 full on
        $display("Time: %0t | Scenario 2 - off and full on", $time);
        check_leds('0, {16'd10, 16'd10, 16'd10}, "off and full on");

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule
