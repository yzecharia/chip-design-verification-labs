import lab7_pkg::*;
import pwm_rgf_pkg::*;

module tb_pwm;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    pwm_cfg_t pwm_cfg = '0;
    logic [TIME_SLOTS_WIDTH-1:0] scaled_val = '0;
    logic pwm_signal, wrap_cnt;

    pwm dut (
        .clk(clk),
        .reset_n(reset_n),
        .pwm_cfg(pwm_cfg),
        .scaled_val(scaled_val),
        .pwm_signal(pwm_signal),
        .wrap_cnt(wrap_cnt)
    );

    int errors = 0;

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert ((pwm_signal === '0) && (wrap_cnt === '0)) else begin
            $error("pwm_signal = %b, wrap_cnt = %b after reset", pwm_signal, wrap_cnt);
            errors++;
        end
        reset_n = '1;
    endtask

    // one period = sweep_time slots of time_slots clocks each
    function int period(input pwm_cfg_t cfg);
        return cfg.sweep_time * cfg.time_slots;
    endfunction

    // counts the high clocks and the wrap_cnt pulses during one full period
    task measure(output int ones, output int wraps);
        ones = 0;
        wraps = 0;
        for (int c = 0; c < period(pwm_cfg); c++) begin
            ones += pwm_signal;
            wraps += wrap_cnt;
            #(CLK_PERIOD);
        end
    endtask

    // the value is high for scaled_val slots, so for scaled_val * time_slots clocks
    task check_duty(input logic [15:0] sweep, slot, input logic [TIME_SLOTS_WIDTH-1:0] v, input string name);
        int ones, wraps;
        $display("Time: %0t | TASK: sweep_time = %0d, time_slots = %0d, scaled_val = %0d", $time, sweep, slot, v);
        pwm_cfg.sweep_time = sweep;
        pwm_cfg.time_slots = slot;
        scaled_val = v;
        #(CLK_PERIOD * 3 * period(pwm_cfg)); // the new value is taken at the end of a period
        measure(ones, wraps);
        assert ((ones == v * slot) && (wraps == 1))
            $display("Time: %0t | PASS: %s, high %0d of %0d clocks", $time, name, ones, period(pwm_cfg));
        else begin
            $error("%s: high %0d clocks (expected %0d), wrap_cnt pulses = %0d (expected 1)", name, ones, v * slot, wraps);
            errors++;
        end
    endtask

    initial begin
        reset_dut();

        // Scenario 1: half of the slots are high, wrap_cnt pulses once in a period
        $display("Time: %0t | Scenario 1 - half duty", $time);
        check_duty(10, 4, 5, "half duty");

        // Scenario 2: value 0 keeps the led off, value = sweep_time keeps it on all the period
        $display("Time: %0t | Scenario 2 - off and full on", $time);
        check_duty(10, 4, 0, "zero duty");
        check_duty(10, 4, 10, "full duty");

        // Scenario 3: a shorter slot (time_slots) makes the period shorter, the duty stays the same
        $display("Time: %0t | Scenario 3 - shorter slot", $time);
        check_duty(10, 2, 5, "time_slots 2");

        // Scenario 4: a different sweep_time changes the period, the duty follows scaled_val
        $display("Time: %0t | Scenario 4 - sweep_time change", $time);
        check_duty(20, 4, 5, "sweep_time 20");
        check_duty(5, 4, 5, "sweep_time 5");

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule
