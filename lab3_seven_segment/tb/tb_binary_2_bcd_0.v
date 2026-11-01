`timescale 1ns/1ps
module tb_binary_2_bcd_0;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg [15:0] sw;
    reg start;
    wire [19:0] bcd;

    binary_2_bcd binary_2_bcd_i (clk, reset_n, sw, start, bcd);

    initial $monitor("Time: %0d | sw=%0d | start=%0b | bcd=%h", $time, sw, start, bcd);

    initial begin
        reset_n = 1'b0; sw = 16'd0; start = 1'b0;
        repeat(2) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;
        repeat(20) @(posedge clk);

        @(negedge clk); sw = 16'd12345; start = 1'b1;
        @(negedge clk); start = 1'b0;
        repeat(20) @(posedge clk);

        @(negedge clk); sw = 16'd65535; start = 1'b1;
        @(negedge clk); start = 1'b0;
        repeat(20) @(posedge clk);

        $finish;
    end

endmodule
