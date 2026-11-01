`timescale 1ns/1ps
module tb_btn_hold_1s_0;

    localparam MAX_TICK = 2;  // tick every 2 clocks
    localparam MAX_COUNT = 5; // 5 ticks = 10 clocks = 100ns

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg click;
    wire tick;
    wire pressed_1s;

    tick_gen #(.MAX_TICK(MAX_TICK)) tick_gen_i (clk, reset_n, tick);
    btn_hold_1s #(.MAX_COUNT(MAX_COUNT)) btn_hold_1s_i (clk, reset_n, click, tick, pressed_1s);

    initial $monitor("Time: %0d | click=%0b | pressed_1s=%0b", $time, click, pressed_1s);

    initial begin
        reset_n = 1'b0; click = 1'b0;
        repeat(2) @(posedge clk);

        @(negedge clk); reset_n = 1'b1;

        // long press
        @(negedge clk); click = 1'b1;
        repeat((MAX_COUNT + 5) * MAX_TICK) @(posedge clk);
        @(negedge clk); click = 1'b0;

        // short press
        @(negedge clk); click = 1'b1;
        repeat((MAX_COUNT - 2) * MAX_TICK) @(posedge clk);
        @(negedge clk); click = 1'b0;

        repeat(10) @(posedge clk);
        $finish;
    end

endmodule
