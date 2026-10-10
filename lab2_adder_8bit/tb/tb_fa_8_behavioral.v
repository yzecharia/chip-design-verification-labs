`timescale 1ns / 1ps


module tb_fa_8_behavioral(

    );
    
    reg [7:0] a, b;
    reg cin;
    wire [7:0] sum;
    wire cout;
    
    fa_8_behavioral fa_i (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
    
    integer i, j;
    
    initial begin
        $monitor("a=%0d, b=%0d, cin=%0d | sum= %0d, cout=%0d", a, b, cin, sum, cout);
    end
    
    initial begin
        for (i = 0; i < (2**8-1); i = i + 1) begin
            for (j = 0; j < (2**8-1); j = j + 1) begin
                a = i; b = j; cin = 1'b0; #10;
                a = i; b = j; cin = 1'b1; #10;
            end
        end
        #10; $finish();
    end
    
endmodule
