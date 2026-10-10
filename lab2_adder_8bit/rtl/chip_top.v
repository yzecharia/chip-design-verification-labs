`timescale 1ns / 1ps


module chip_top(
    input [15:0] SW,
    input BTNC,
    output [8:0] LED
    );

    
    fa_8_structural_flat fa_i (.a(SW[7:0]), .b(SW[15:8]), .cin(BTNC), .sum(LED[7:0]), .cout(LED[8]));
endmodule
