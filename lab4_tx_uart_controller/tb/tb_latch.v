`timescale 1ns/1ps
module tb_latch;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n, ready;
    reg [11:0] sw_d;
    reg held;

    wire [7:0] data;
    wire [1:0] delay, size;
    wire transmit;

    latch latch_i(clk, reset_n, ready, sw_d, held, data, delay, size, transmit);

    // held comes from btn_hold

    initial $monitor("Time: %0d | held=%0b | sw_d=%0h | ready=%0b | data=%0h | delay=%0d | size=%0d | transmit=%0b", $time, held, sw_d, ready, data, delay, size, transmit);

    initial begin
        reset_n = 1'b0; ready = 1'b0; sw_d = 12'h000; held = 1'b0;
        repeat(2) @(posedge clk);
        @(negedge clk) reset_n = 1'b1;

        @(negedge clk); sw_d=12'hABC; held = 1'b1; ready = 1'b1;
        @(negedge clk); held = 1'b0; ready = 1'b0;

        @(negedge clk); sw_d=12'hABA; ready = 1'b1;
        @(negedge clk); sw_d=12'hFFF;
        @(negedge clk); sw_d=12'h555; held = 1'b1;
        @(negedge clk); ready = 1'b0;

        @(negedge clk); sw_d = 12'h111; held = 1'b0;
        @(negedge clk); held = 1'b0;
        @(negedge clk); held = 1'b1;
        @(negedge clk); ready = 1'b1;

        repeat(5) @(posedge clk);

        $finish;


    end

endmodule
