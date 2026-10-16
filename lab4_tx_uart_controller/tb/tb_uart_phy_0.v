`timescale 1ns/1ps
module tb_uart_phy_0;

localparam BAUD_RATE = 10000000; // 100M / 10M = 10 cycles per bit
localparam CYCLES_PER_BIT = 100000000 / BAUD_RATE; // = 10
localparam FRAME_CYCLES = CYCLES_PER_BIT * 10 + 10;

reg clk = 1'b0;
always #5 clk = !clk;

reg reset_n;
reg [7:0] data;
reg start;

wire tx;
wire done;


uart_phy #(.BAUD_RATE(BAUD_RATE)) uart_phy_i (clk, reset_n, data, start, tx, done);

initial $monitor("Time: %0d | data=%0h | start=%0b | tx=%0b | done=%0b", $time, data, start, tx, done);

initial begin
    reset_n = 1'b0; data =8'b0; start = 1'b0;
    repeat(2) @(negedge clk);
    @(negedge clk); reset_n = 1'b1;

    // Drive 0xA5
    @(negedge clk); data = 8'hA5; start = 1'b1;
    @(negedge clk); start = 1'b0;

    repeat(FRAME_CYCLES) @(posedge clk);

    // Drive 0x00
    @(negedge clk); data = 8'h00; start = 1'b1;
    @(negedge clk); start = 1'b0;

    repeat(FRAME_CYCLES) @(posedge clk);

    // Drive 0xFF
    @(negedge clk); data = 8'hFF; start = 1'b1;
    @(negedge clk); start = 1'b0;

    repeat(FRAME_CYCLES) @(posedge clk);

    $finish;
end


endmodule
