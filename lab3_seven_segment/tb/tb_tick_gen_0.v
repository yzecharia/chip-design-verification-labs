`timescale 1ns/1ps
module tb_tick_gen_0;

    localparam MAX_TICK = 5;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    wire tick;

    tick_gen #(.MAX_TICK(MAX_TICK)) tick_gen_i (clk, reset_n, tick);

    initial $monitor("Time: %0d | reset_n=%0b | tick=%0b", $time, reset_n, tick);

    initial begin
        reset_n = 1'b0;
        repeat(2) @(posedge clk);

        @(negedge clk); reset_n = 1'b1;
        repeat(18) @(posedge clk);

        // reset in the middle of a count
        @(negedge clk); reset_n = 1'b0;
        @(negedge clk); reset_n = 1'b1;
        repeat(12) @(posedge clk);

        $finish;
    end

endmodule
