`timescale 1ns/1ps
module tb_binary_2_bcd (
    
);
    reg [15:0] sw;
    reg start;
    wire [19:0] bcd;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n;

    integer pass = 0, fail = 0;

    binary_2_bcd bin2bcd_i (clk, reset_n, sw, start, bcd);

    task reset ();
        begin
            @(negedge clk);
            reset_n = 1'b0;

            repeat (3) @(negedge clk);
            reset_n = 1'b1;
            @(negedge clk);
        end
    endtask

    function [19:0] bin2bcd (input [15:0] bin);
        integer i;
        integer bin_num;
        begin
            if (start) bin2bcd = 20'd0;
            else begin
                bin_num = bin;
                for (i = 0; i < 5; i = i + 1) begin
                    bin2bcd[4*i +: 4] = bin_num % 10;
                    bin_num = bin_num / 10;
                end
            end
        end
    endfunction

    task drive (input [15:0] switches);
        begin
            @(negedge clk);
            sw = switches;
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            repeat (16) @(negedge clk);
            check_bcd(bcd, bin2bcd(sw));
        end
    endtask

    task drive_random();
        begin
            drive($urandom);
        end
    endtask

    task check_bcd (input [19:0] actual_bcd, input [19:0] expected_bcd);
        reg res;
        begin
            res = (actual_bcd === expected_bcd);
            $display("Time: %5d | Check BCD conversion correct | sw=%b | actual_bcd=%20b | expected_bcd=%20b | %s", $time, sw, actual_bcd, expected_bcd, (res) ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    initial begin
        reset();
        // max num is 65535
        // 1. check that start actually puts zeros into bcd
        @(negedge clk); sw = 16'd12345; start = 1'b1; @(posedge clk); #1; check_bcd(bcd, bin2bcd(sw));
        @(negedge clk); start = 1'b0;

        // 2. check max value min value and all the numbers
        drive(16'd0);
        drive(16'd65535);
        drive(16'd12345);
        drive(16'd67890);

        // 3. 20 random checks
        repeat (20) drive_random();

        // Summary
        if (fail == 0) $display("Time: %5d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %5d | TEST FAIL | %0d/%0d", $time, pass, pass + fail);
        $finish();
    end

endmodule
