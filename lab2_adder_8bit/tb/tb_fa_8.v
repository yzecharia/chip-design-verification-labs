`timescale 1ns / 1ps


module tb_fa_8(

    );
    
    reg [7:0] a, b;
    reg cin;
    wire [7:0] sum_b, sum_s;
    wire cout_b, cout_s;
    
    fa_8_behavioral fa_b_i (a, b, cin, sum_b, cout_b);
    fa_8_structural_flat fa_s_i (a, b, cin, sum_s, cout_s);
    
    initial $monitor("Time: %0d | a: %0d | b: %0d | cin: %0d | Beh Sum: %0d | Beh Cout: %0d | Str Sum: %0d | Str Cout: %0d", $time, a, b, cin, sum_b, cout_b, sum_s, cout_s);
    
    
    initial begin
        a=8'd2; b=8'd5; cin=1'b0; #10; // No cout
        a=8'd210; b=8'd150; cin=1'b0; #10; // cout
        a=8'd255; b=8'd0; cin=1'b0; #10; // Max value w/o cout
        a=8'd255; b=8'd255; cin=1'b1; #10; // Max overflow
        a=8'd255; b=8'd0; cin=1'b1; #10; // Ripple carry
        
        #10; $finish;
    end
    
endmodule
