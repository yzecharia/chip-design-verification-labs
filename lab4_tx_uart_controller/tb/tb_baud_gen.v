`timescale 1ns/1ps  
module tb_baud_gen;

    localparam BAUD_RATE = 10000000;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg en;
    wire baud_tick;

    baud_gen #(.BAUD_RATE(BAUD_RATE)) baud_gen_i(clk, reset_n, en, baud_tick);

    initial $monitor("Time: %0d | en=%0b | baud_tick=%0b", $time, en, baud_tick);

    initial begin
        reset_n = 1'b0; en = 1'b0;
        repeat(2) @(posedge clk);

        @(negedge clk); reset_n = 1'b1; en = 1'b1;
        repeat(20) @(posedge clk);

        @(negedge clk); en = 1'b0;
        repeat(10) @(posedge clk);

        $finish;
    end

endmodule
