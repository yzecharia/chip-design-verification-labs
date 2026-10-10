`timescale 1ns / 1ps

module fa_8_behavioral(
    input [7:0] a, b,
    input cin,
    output [7:0] sum,
    output cout
    );
    
    assign {cout, sum} = {1'b0, a} + {1'b0, b} + {8'b0, cin};
endmodule
