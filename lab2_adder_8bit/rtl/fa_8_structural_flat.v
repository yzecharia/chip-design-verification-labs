`timescale 1ns / 1ps


module fa_8_structural_flat(
    input [7:0] a, b,
    input cin,
    output [7:0] sum,
    output cout
    );
    
    wire [8:0] carry;
    genvar i;
    
    generate
        for (i = 0; i < 8; i = i + 1) begin : ripple_adder
            assign sum[i] = a[i] ^ b[i] ^ carry[i];
            assign carry[i+1] = carry[i] & (a[i] ^ b[i]) | a[i] & b[i];
        end
    endgenerate 
    
    assign carry[0] = cin;
    assign cout = carry[8];
endmodule
