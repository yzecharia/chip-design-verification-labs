`timescale 1ns/1ps
module tb_value_latch_0;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg pressed_c, pressed_d;
    reg [15:0] sw;

    wire dec_hex;
    wire [15:0] sw_reg;

    value_latch value_latch_i (clk, reset_n, pressed_c, pressed_d, sw, dec_hex, sw_reg);

    // pressed_c / pressed_d come from btn_hold_1s

    initial $monitor("Time: %0d | pressed_c=%0b | pressed_d=%0b | sw=%h | dec_hex=%0b | sw_reg=%h", $time, pressed_c, pressed_d, sw, dec_hex, sw_reg);

    initial begin
        reset_n = 1'b0; pressed_c = 1'b0; pressed_d = 1'b0; sw = 16'h0000;
        repeat(2) @(posedge clk);
        @(negedge clk); reset_n = 1'b1;

        // switches change without a press
        @(negedge clk); sw = 16'h1234;
        @(negedge clk); sw = 16'hABCD;

        // center press -> latch, decimal
        @(negedge clk); pressed_c = 1'b1;
        @(negedge clk); pressed_c = 1'b0; sw = 16'hFFFF;

        // down press -> latch, hex
        @(negedge clk); pressed_d = 1'b1;
        @(negedge clk); pressed_d = 1'b0; sw = 16'h0309;

        @(negedge clk); pressed_c = 1'b1;
        @(negedge clk); pressed_c = 1'b0; sw = 16'h5555;

        // both together
        @(negedge clk); pressed_c = 1'b1; pressed_d = 1'b1;
        @(negedge clk); pressed_c = 1'b0; pressed_d = 1'b0;

        // reset
        @(negedge clk); reset_n = 1'b0;
        @(negedge clk); reset_n = 1'b1;

        repeat(5) @(posedge clk);

        $finish;
    end

endmodule
