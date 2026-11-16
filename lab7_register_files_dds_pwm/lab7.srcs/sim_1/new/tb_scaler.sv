import lab7_pkg::*;
import pwm_rgf_pkg::*;

module tb_scaler;
    timeunit 1ns;
    timeprecision 1ps;

    corrected_pixel_t led_mux_val = '0;
    pwm_cfg_t pwm_cfg = '0;
    scaled_val_t scaled_vals;

    scaler dut (
        .led_mux_val(led_mux_val),
        .pwm_cfg(pwm_cfg),
        .scaled_vals(scaled_vals)
    );

    int errors = 0;

    // value in the 0..1023 scale moved to the 0..sweep_time scale
    function logic [TIME_SLOTS_WIDTH-1:0] exp_scale(input logic [GAMMA_WIDTH-1:0] v, input logic [15:0] sweep);
        int p;
        p = v * sweep;
        return p / 1024;
    endfunction

    task check(input logic [GAMMA_WIDTH-1:0] r, g, b, input logic [15:0] sweep, input string name);
        $display("Time: %0t | TASK: r = %0d, g = %0d, b = %0d, sweep_time = %0d", $time, r, g, b, sweep);
        led_mux_val = {r, g, b};
        pwm_cfg.sweep_time = sweep;
        #(CLK_PERIOD);
        assert ((scaled_vals[2] === exp_scale(r, sweep)) &&
                (scaled_vals[1] === exp_scale(g, sweep)) &&
                (scaled_vals[0] === exp_scale(b, sweep)))
            $display("Time: %0t | PASS: %s", $time, name);
        else begin
            $error("%s: got %0d %0d %0d, expected %0d %0d %0d", name,
                   scaled_vals[2], scaled_vals[1], scaled_vals[0],
                   exp_scale(r, sweep), exp_scale(g, sweep), exp_scale(b, sweep));
            errors++;
        end
    endtask

    initial begin
        // Scenario 1: sweep_time = 1024 keeps the values as they are
        $display("Time: %0t | Scenario 1 - same scale", $time);
        check(1023, 512, 0, 1024, "sweep_time 1024");

        // Scenario 2: sweep_time = 100 moves the values to a 0..100 scale
        $display("Time: %0t | Scenario 2 - smaller scale", $time);
        check(1023, 512, 256, 100, "sweep_time 100");

        // Scenario 3: the largest value with the largest sweep_time does not overflow
        $display("Time: %0t | Scenario 3 - largest values", $time);
        check(1023, 1023, 1, 16'hFFFF, "sweep_time 65535");

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule
