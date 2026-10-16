`timescale 1ns/1ps
module tb_display_ctrl;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    wire tick;
    reg [7:0] data;
    reg [1:0] delay, size;
    reg [8:0] row;
    wire [7:0]an;
    wire [6:0] seg;
    wire dp;
    reg tick_en;

    baud_gen #(.BAUD_RATE(10000000)) baud_gen_i(clk, reset_n, tick_en, tick);
    display_ctrl display_ctrl_i(clk, reset_n, tick, data, delay, size, row, an, seg, dp);

    integer i, j, k;

    initial $monitor("Time: %0d | data=%h | delay=%d | size=%d | tick_en=%0b | row=%b | an=%b | seg=%b | dp=%0b", $time, data, delay, size, tick_en, row, an, seg, dp);

    initial begin
        reset_n = 1'b0; data = 8'h00; delay=2'd0; size = 2'd0; tick_en = 1'b0; row=9'd0;
        repeat(2) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;

        @(negedge clk); data = 8'hAA; 
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                @(negedge clk); delay = i[1:0]; size = j[1:0]; tick_en = 1'b1;
                repeat(10) @(posedge clk);
                @(negedge clk) tick_en = 1'b0; row = row + 1;
            end
        end

        @(negedge clk); data = 8'h55; delay = 2'd0; size = 2'd0; tick_en = 1'b1;
        repeat(5) @(posedge clk);
        @(negedge clk); reset_n = 1'b0; row = 9'd0; 
        @(negedge clk); reset_n = 1'b1;
        repeat(10) @(posedge clk);

        @(negedge clk); row = 9'h0ff;
        repeat(10) @(posedge clk);
        @(negedge clk); row = 9'h100;
        repeat(10) @(posedge clk);
        @(negedge clk); row = 9'h000;
        repeat(15) @(posedge clk);

    

        $finish;
    end


endmodule
