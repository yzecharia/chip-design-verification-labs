`timescale 1ns/1ps
module tb_ss ();

    reg [3:0] dig_in;
    wire [6:0] ss_dig;

    reg [4:0] pass = 0, fail = 0;
    reg [4:0] expected_dig_in;

    seven_segment ss_i (dig_in, ss_dig);
    integer i;

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            dig_in = i[3:0]; #10;
            expected_dig_in = ss2dig(ss_dig);
            $display("Time:%5d | digit:%1h | decoded:%1h | ss:%b | %s", $time, i, expected_dig_in, ss_dig, (expected_dig_in==i[4:0]) ? "PASS" : "FAIL");
            if (expected_dig_in == i[4:0]) begin
                pass = pass + 1;
            end else begin
                fail = fail + 1;
            end
        end

        #10;
        if (fail == 0) $display("Time: %0d | TEST PASS %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %0d | TEST FAIL %0d/%0d", $time, fail, pass + fail);
        $finish();
    end

    function [4:0] ss2dig (input [6:0] ss_dig);
        begin
            case(ss_dig)
                7'b0000001: ss2dig = 5'h0;
                7'b1001111: ss2dig = 5'h1;
                7'b0010010: ss2dig = 5'h2;
                7'b0000110: ss2dig = 5'h3;
                7'b1001100: ss2dig = 5'h4;
                7'b0100100: ss2dig = 5'h5;
                7'b0100000: ss2dig = 5'h6;
                7'b0001111: ss2dig = 5'h7;
                7'b0000000: ss2dig = 5'h8;
                7'b0000100: ss2dig = 5'h9;
                7'b0001000: ss2dig = 5'ha;
                7'b1100000: ss2dig = 5'hb;
                7'b0110001: ss2dig = 5'hc;
                7'b1000010: ss2dig = 5'hd;
                7'b0110000: ss2dig = 5'he;
                7'b0111000: ss2dig = 5'hf;
                default ss2dig = 5'b10000;
            endcase
        end
    endfunction

endmodule
