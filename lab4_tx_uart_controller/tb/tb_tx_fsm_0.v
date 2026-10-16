`timescale 1ns/1ps  
module tb_tx_fsm_0;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg [7:0] data;
    reg [1:0] size, delay;
    reg transmit;
    wire done;
    wire [7:0] drive_data;
    wire start;
    wire led0;
    wire [8:0] row_out;
    wire ready;
    wire tx;

    uart_phy #(.BAUD_RATE(10000000)) uart_phy_i (clk, reset_n, drive_data, start, tx, done);
    tx_fsm #(.DELAY50(10)) tx_fsm_i(clk, reset_n, data, delay, size, transmit, done, drive_data, start, led0, row_out, ready);

    initial begin
        reset_n = 1'b0; data = 8'b0; size = 2'b0; delay = 2'b0; transmit = 1'b0;
        repeat(2) @(posedge clk);

        reset_n = 1'b1;

        // 1. data = 0x41 delay 0 size 0
        $display("Time: %0d | data=0x41 | size=0 | delay=0", $time);
        @(negedge clk); data = 8'h41; transmit = 1'b1;
        @(negedge clk); transmit = 1'b0;
        while (!ready) @(posedge clk);

        // 2. delay 1, size 1, data=0x55
        $display("Time: %0d | data=0x55 | delay=1 | size=1", $time);
        @(negedge clk); data = 8'h55; delay =2'd1; size = 2'd1; transmit = 1'b1;
        @(negedge clk); transmit = 1'b0;
        while (!ready) @(posedge clk);

        // 3. delay 3, size 1, data=0xAA
        $display("Time: %0d | data=0xAA | delay=3 | size=1", $time);
        @(negedge clk); data = 8'hAA; delay =2'd3; size = 2'd1; transmit = 1'b1;
        @(negedge clk); transmit = 1'b0;
        while (!ready) @(posedge clk);

        $finish;
        
    end

endmodule
