`timescale 1ns/1ps
module tb_chip_top_0;

localparam MAX_TICK = 2;  // tick every 2 clocks
localparam MAX_COUNT = 5; // 5 ticks = 10 clocks = 100ns
localparam LONG_HOLD = (MAX_COUNT + 2) * MAX_TICK;
localparam SCAN = 5 * MAX_TICK; // one round of the 5 digits

reg clk = 1'b0;
always #5 clk = !clk;

reg cpu_resetn;
reg [15:0] sw;
reg btnc, btnd;

wire dp;
wire [6:0] ss_dig;
wire [7:0] disp_an;


chip_top #(.MAX_TICK(MAX_TICK), .MAX_COUNT(MAX_COUNT)) chip_top_i (clk, cpu_resetn, sw, btnc, btnd, dp, ss_dig, disp_an);


initial begin
    cpu_resetn = 1'b1; sw = 16'h0000; btnc = 1'b0; btnd = 1'b0;
    while (chip_top_i.reset_n_sync !== 1'b1) @(posedge clk); // wait for the reset synchronizer

    // 1. SW = 12345, BTNC -> decimal
    $display("Time: %0d | SW=12345 | BTNC (decimal)", $time);
    @(negedge clk); sw = 16'd12345;
    @(negedge clk); btnc = 1'b1;
    repeat(LONG_HOLD) @(posedge clk);
    @(negedge clk); btnc = 1'b0;
    repeat(4 * SCAN) @(posedge clk);

    // 2. SW = 0x0309, BTND -> hex
    $display("Time: %0d | SW=0x0309 | BTND (hex)", $time);
    @(negedge clk); sw = 16'h0309;
    @(negedge clk); btnd = 1'b1;
    repeat(LONG_HOLD) @(posedge clk);
    @(negedge clk); btnd = 1'b0;
    repeat(4 * SCAN) @(posedge clk);

    $finish;
end


endmodule
