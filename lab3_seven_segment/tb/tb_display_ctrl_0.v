`timescale 1ns/1ps
module tb_display_ctrl_0;

    localparam MAX_TICK = 4; // tick every 4 clocks

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    wire tick;
    reg dec_hex;
    reg [15:0] hex_val;
    reg [19:0] bcd_val;
    wire [7:0] display_an;
    wire [6:0] ss_dig;
    wire dp;

    tick_gen #(.MAX_TICK(MAX_TICK)) tick_gen_i (clk, reset_n, tick);
    display_ctrl display_ctrl_i (clk, reset_n, tick, dec_hex, hex_val, bcd_val, display_an, ss_dig, dp);

    initial $monitor("Time: %0d | dec_hex=%0b | hex_val=%h | bcd_val=%h | display_an=%b | ss_dig=%b | dp=%0b", $time, dec_hex, hex_val, bcd_val, display_an, ss_dig, dp);

    initial begin
        reset_n = 1'b0; dec_hex = 1'b0; hex_val = 16'h0000; bcd_val = 20'h00000;
        repeat(2) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;

        // hex mode: 4 digits
        @(negedge clk); hex_val = 16'hABCD; bcd_val = 20'h43981; // 0xABCD = 43981
        repeat(6 * MAX_TICK) @(posedge clk);

        // decimal mode: 5 digits
        @(negedge clk); dec_hex = 1'b1;
        repeat(6 * MAX_TICK) @(posedge clk);

        // reset in the middle of the scan
        @(negedge clk); reset_n = 1'b0;
        @(negedge clk); reset_n = 1'b1;
        repeat(3 * MAX_TICK) @(posedge clk);

        $finish;
    end

endmodule
