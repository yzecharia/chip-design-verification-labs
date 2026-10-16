`timescale 1ns/1ps
module tb_btn_hold;

    localparam MAX_COUNT = 10;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg btn;
    wire held;

    btn_hold #(.MAX_COUNT(MAX_COUNT)) btn_hold_i (clk, reset_n, btn, held);

    initial $monitor("Time: %0d | btn=%0b | held=%0b", $time, btn, held);

    initial begin
        reset_n = 1'b0; btn = 1'b0;
        repeat(2) @(posedge clk);

        @(negedge clk); reset_n = 1'b1;
        @(negedge clk); btn = 1'b1;
        repeat(MAX_COUNT + 5) @(posedge clk);
        @(negedge clk) btn = 1'b0;

        @(negedge clk); btn = 1'b1;
        repeat(MAX_COUNT - 2) @(posedge clk);
        @(negedge clk); btn = 1'b0;

        repeat(10) @(posedge clk);
        $finish;
    end



endmodule
