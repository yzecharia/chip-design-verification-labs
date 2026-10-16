`timescale 1ns/1ps
module tb_chip_top_0;

localparam BAUD_RATE = 10000000; // 100M / 10M = 10 cycles per bit
localparam DISPLAY_RR = 10000000; // tick every 10 cycles
localparam MAX_COUNT_DEBOUNCE = 4;
localparam MAX_COUNT_BTN_HOLD = 10; // 10 cycles = 100ns
localparam DELAY50 = 20;

localparam LONG_HOLD = MAX_COUNT_BTN_HOLD + 1;

reg clk = 1'b0;
always #5 clk = !clk;

reg cpu_reset;
reg btnc;
reg [11:0] sw;

wire tx;
wire led0;
wire [7:0] an;
wire [6:0] seg;
wire dp;


chip_top #(.BAUD_RATE(BAUD_RATE), .DISPLAY_RR(DISPLAY_RR), .MAX_COUNT_DEBOUNCE(MAX_COUNT_DEBOUNCE), .MAX_COUNT_BTN_HOLD(MAX_COUNT_BTN_HOLD), .DELAY50(DELAY50)) chip_top_i (clk, cpu_reset, btnc, sw, tx, led0, an, seg, dp);


initial begin
    cpu_reset = 1'b1; btnc = 1'b0; sw = 12'b0;
    while (chip_top_i.reset_n !== 1'b1) @(posedge clk); // wait for the power-on reset

    // 1. data = 0x41 delay 0 size 0
    $display("Time: %0d | data=0x41 | delay=0 | size=0", $time);
    @(negedge clk); sw = {2'd0, 2'd0, 8'h41};
    @(negedge clk); btnc = 1'b1;
    repeat(LONG_HOLD) @(posedge clk);
    @(negedge clk); btnc = 1'b0;

    while (chip_top_i.ready) @(posedge clk); // run started
    while (!chip_top_i.ready) @(posedge clk); // run ended

    // 2. data = 0x23 delay 1 size 1
    $display("Time: %0d | data=0x23 | delay=1 | size=1", $time);
    @(negedge clk); sw = {2'd1, 2'd1, 8'h23};
    @(negedge clk); btnc = 1'b1;
    repeat(LONG_HOLD) @(posedge clk);
    @(negedge clk); btnc = 1'b0;

    while (chip_top_i.ready) @(posedge clk);
    while (!chip_top_i.ready) @(posedge clk);

    repeat(100) @(posedge clk);

    $finish;
end


endmodule
