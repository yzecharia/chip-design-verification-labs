`timescale 1ns/1ps
module tb_display_ctrl ();
    reg clk = 0;
    always #5 clk = ~clk;

    reg reset_n;

    reg tick = 1'b0;
    reg dec_hex;
    reg [15:0] hex_val;
    reg [19:0] bcd_val;

    reg [7:0] exp_display_an;

    wire [7:0] display_an;
    wire [6:0] ss_dig;
    wire dp;

    integer pos;

    integer pass = 0, fail = 0;

    task reset();
        begin
            $display("Time: %5d | Applied reset", $time);
            @(negedge clk);
            reset_n = 1'b0;
            exp_display_an = 8'b11111110;

            repeat (3) @(negedge clk);
            reset_n = 1'b1;
            pos = 0;
            display_an_checker("display_an after reset", display_an, exp_display_an);
        end
    endtask

    display_ctrl display_ctrl_i (clk, reset_n, tick, dec_hex, hex_val, bcd_val, display_an, ss_dig, dp);

    function [19:0] bin2bcd (input [15:0] bin_num);
        integer num;
        integer i;
        begin
            i = 0;
            num = bin_num;
            for (i = 0; i < 5; i = i + 1) begin
                bin2bcd[4*i +: 4] = num % 10;
                num = num / 10;
            end
        end
    endfunction

    task drive (input [15:0] switch);
        begin
            hex_val = switch;
            bcd_val = bin2bcd(switch);
        end
    endtask

    task drive_random ();
        begin
            drive($urandom);
        end
    endtask
    
    task gen_tick ();
        begin
            if (reset_n) begin
                repeat (2) @(negedge clk);
                tick = 1'b1;

                @(negedge clk); tick = 1'b0;
                // need to move pos here.
                // pos can go from 0 -> 4 (5 places), but keeps incrementing
                // to find place (% 5)
                pos = (pos + 1) % 5;
                display_an_checker("display_an after tick", display_an, exp_an(pos, dec_hex));
                check_ss_dig(ss_dig);
            end
        end
    endtask

    task display_an_checker (input [8*40:1] s, input [7:0] actual, input [7:0] expected);
        reg res;
        begin
            res = (actual === expected);
            $display("Time: %5d | %0s | actual=%b | expected=%b | %0s", $time, s, actual, expected, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    function [7:0] exp_an (input integer pos, input dec_hex);
        begin
            case(pos)
                0: exp_an = 8'b1111_1110;
                1: exp_an = 8'b1111_1101;
                2: exp_an = 8'b1111_1011;
                3: exp_an = 8'b1111_0111;
                4: exp_an = dec_hex ? 8'b1110_1111 : 8'b1111_1111;
                default: exp_an = 8'bxxxx_xxxx; // checker has === 
            endcase
        end
    endfunction

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

    // One of the outputs of display_ctrl is ss_dig. The current digit in ss code to display.
    // I have the correct position of what is supposed to be displayed, what is being displayed,
    // a way to convert what is displayed back to a number,
    // so I need to check that after i convert back to a number that the number in bcd_val/hex_val at current 
    // pos is equal to ss_dig
    task check_ss_dig (input [6:0] ss_digit);
        reg [4:0] converted_num;
        reg res;
        reg [3:0] expected_num;
        begin
            // 1. convert ss_dig back to a number
            converted_num = ss2dig(ss_digit);
            
            // 2. Now I have the converted number, need to check if bcd_val in pos is equal to that number
            if (dec_hex | pos != 4) begin
                if (converted_num[4]) begin
                    $display("Time: %5d | Error: ss_dig is not a valid digit pattern | ss_dig=%b | FAIL", $time, ss_digit);
                    fail = fail + 1;
                end else begin
                    expected_num = dec_hex ? bcd_val[4*pos +: 4] : hex_val[4*pos +: 4];
                    res = (expected_num === converted_num[3:0]);
                    $display("Time: %5d | Check ss_dig at pos %0d is correct | actual=%0d | expected=%0d | %s", $time, pos, converted_num[3:0], expected_num, res ? "PASS" : "FAIL");
                    if (res) pass = pass + 1;
                    else fail = fail + 1;
                end
            end
        end
    endtask

    task gen_5_tick ();
        begin
            repeat (5) gen_tick();
        end
    endtask 


    integer j;
    initial begin
        dec_hex = 0;
        reset();

        repeat (20) @(negedge clk);
        display_an_checker("display_an stable without tick", display_an, exp_an(pos, dec_hex));

        drive(0);
        gen_5_tick();
        drive(16'h0123);
        gen_5_tick();
        drive(16'h4567);
        gen_5_tick();
        drive(16'h89ef);
        gen_5_tick();
        drive(16'hffff);
        gen_5_tick();
        drive(16'habcd);
        gen_5_tick();
        drive(16'ha2b2);
        gen_5_tick();

        dec_hex = 1'b1;
        drive(16'd0);
        gen_5_tick();
        drive(16'd1234);
        gen_5_tick();
        drive(16'd56789);
        gen_5_tick();
        drive(16'd65535);
        gen_5_tick();
        drive(16'd24680);
        gen_5_tick();

        dec_hex = 1'b1; drive(16'd12345);
        repeat (4) gen_tick();
        dec_hex = 1'b0; #1;
        display_an_checker("AN4 off right after switch to hex", display_an, exp_an(pos, dec_hex));
        @(negedge clk);
        repeat (6) gen_tick();

        dec_hex = 1'b1; drive(16'd11111);
        repeat (2) gen_tick();
        drive(16'd54321);
        repeat (3) gen_tick();

        for (j=0; j<40; j=j+1) begin
            dec_hex = j[0];
            drive_random();
            gen_5_tick();
        end

        #20;
        if (fail == 0) $display("Time: %5d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %5d | TEST FAIL | %0d/%0d", $time, fail, pass + fail);

        $finish();

    end
endmodule
