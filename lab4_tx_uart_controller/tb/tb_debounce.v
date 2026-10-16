`timescale 1ns/1ps
module tb_debounce;

    localparam MAX_COUNT = 10;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg cpu_reset, btnc;
    reg [11:0] sw;
    wire [11:0] sw_d;
    wire btnc_d;
    wire cpu_reset_d;

    debounce #(.MAX_COUNT(MAX_COUNT)) debounce_i (clk, cpu_reset, btnc, sw, sw_d, btnc_d, cpu_reset_d);

    initial $monitor("Time: %0d | cpu_reset=%0b | cpu_reset_d=%0b | btnc=%0b | btnc_d=%0b | sw=%0h| sw_d=%0h", $time, cpu_reset, cpu_reset_d, btnc, btnc_d, sw, sw_d);

    initial begin
        // power on reset wait for sync + edge to finish;
        cpu_reset = 1'b1; sw = 12'b0; btnc=1'b0;

        while (!debounce_i.reset_n == 1'b1) @(posedge clk);

        // test sw change
        @(negedge clk); sw = 12'hABC; 
        repeat(MAX_COUNT + 3) @(posedge clk);
        
        // test switch dont change
        @(negedge clk) sw = 12'b0;
        repeat(MAX_COUNT - 1) @(posedge clk);
        @(negedge clk); sw = 12'hABC;

        //switch back to 0 and test btnc
        @(negedge clk); sw = 12'b0; btnc = 1'b1;
        repeat(MAX_COUNT + 3) @(posedge clk); // Here sw change back to zero
        @(negedge clk); btnc = 1'b0; 

        // test if btnc doesnt change because wait not long enough
        repeat(MAX_COUNT -1) @(posedge clk);
        @(negedge clk); btnc = 1'b1;

        // cheack reset works in middle of change
        @(negedge clk); btnc = 1'b0; sw = 12'hABA;
        @(negedge clk); cpu_reset = 1'b0;
        repeat(MAX_COUNT + 3) @(posedge clk);

        @(negedge clk); cpu_reset = 1'b1;
        repeat(5) @(posedge clk);


    
        $finish;
        

    end

endmodule
