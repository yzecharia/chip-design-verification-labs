`timescale 1ns/1ps

module tb_seven_segment;
    reg clk = 1'b0;
    always #5 clk = !clk;
    
    reg [3:0] dig_in;
    wire [6:0] ss_dig;

    seven_segment seven_segment_i (dig_in, ss_dig);

    integer i;

    initial $monitor("Time: %0d | dig_in=%0h | ss_dig = %b", $time, dig_in, ss_dig);

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            dig_in = i;
            repeat(2) @(posedge clk);
        end
        $finish;
    end


endmodule
