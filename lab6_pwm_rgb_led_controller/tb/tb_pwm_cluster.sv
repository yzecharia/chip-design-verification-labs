import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_pwm_cluster;
    timeunit 1ns;
    timeprecision 1ps;

    localparam SLOTS = `SLOTS;
    localparam SLOTS_WIDTH = $clog2(SLOTS);

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic [2:0][SLOTS_WIDTH-1:0] value = '0;
    logic pwm_led = '0;
    logic [2:0] led16, led17;

    pwm_cluster #(.SLOTS(SLOTS)) dut (
        .clk(clk),
        .reset_n(reset_n),
        .value(value),
        .pwm_led(pwm_led),
        .led16(led16),
        .led17(led17)
    );

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(led16 === '0) else $error("led16 = %b after reset", led16);
        assert(led17 === '0) else $error("led17 = %b after reset", led17);
        reset_n = '1;
    endtask

    // count ones on all six pins over SLOTS consecutive cycles (any window of a full period gives the duty)
    task measure(output int ones16 [2:0], output int ones17 [2:0]);
        for (int i = 0; i < 3; i++) begin ones16[i] = 0; ones17[i] = 0; end
        for (int c = 0; c < SLOTS; c++) begin
            for (int i = 0; i < 3; i++) begin ones16[i] += led16[i]; ones17[i] += led17[i]; end
            #(CLK_PERIOD);
        end
    endtask

    task drive(input logic [2:0][SLOTS_WIDTH-1:0] v, input logic sel);
        int ones16 [2:0], ones17 [2:0];
        $display("Time: %0t | TASK: Drive value r=%0d g=%0d b=%0d, pwm_led=%b", $time, v[2], v[1], v[0], sel);
        value = v; pwm_led = sel;
        #(CLK_PERIOD * 2 * SLOTS);                 // the pwm latches at its period boundary
        measure(ones16, ones17);
        for (int i = 0; i < 3; i++) begin
            if (sel) begin
                assert(ones17[i] === v[i]) else $error("led17[%0d] duty = %0d, expected %0d", i, ones17[i], v[i]);
                assert(ones16[i] === 0) else $error("led16[%0d] duty = %0d, expected 0 (led17 selected)", i, ones16[i]);
            end else begin
                assert(ones16[i] === v[i]) else $error("led16[%0d] duty = %0d, expected %0d", i, ones16[i], v[i]);
                assert(ones17[i] === 0) else $error("led17[%0d] duty = %0d, expected 0 (led16 selected)", i, ones17[i]);
            end
        end
    endtask

    initial begin
        reset_dut();

        // 1. three different duties on LED16, LED17 off
        drive({SLOTS_WIDTH'(SLOTS / 2), SLOTS_WIDTH'(SLOTS / 4), SLOTS_WIDTH'(1)}, '0);

        // 2. same values moved to LED17
        drive({SLOTS_WIDTH'(SLOTS / 2), SLOTS_WIDTH'(SLOTS / 4), SLOTS_WIDTH'(1)}, '1);

        // 3. edges: 0 and SLOTS-1
        drive({SLOTS_WIDTH'(0), SLOTS_WIDTH'(SLOTS - 1), SLOTS_WIDTH'(0)}, '1);
        drive({SLOTS_WIDTH'(SLOTS - 1), SLOTS_WIDTH'(0), SLOTS_WIDTH'(SLOTS - 1)}, '0);

        #(CLK_PERIOD); $finish;
    end

endmodule
