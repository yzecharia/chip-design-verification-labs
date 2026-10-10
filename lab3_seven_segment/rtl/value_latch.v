`timescale 1ns/1ps
module value_latch (
    input clk, reset_n,
    input pressed_c, pressed_d,
    input [15:0] sw,
    output reg dec_hex,     // When 1 decimal is pressed, when 0 hex is pressed, reseted to hex view
    output reg [15:0] sw_reg
);
    always @(posedge clk) begin
        if (!reset_n | pressed_d) dec_hex <= 1'b0;
        else if (pressed_c) dec_hex <= 1'b1;
    end 
    
    always @(posedge clk) begin
        if (!reset_n) sw_reg <= 16'b0;
        else if (pressed_c | pressed_d) sw_reg <= sw;
    end

endmodule
