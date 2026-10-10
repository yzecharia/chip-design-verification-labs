// I pressed X what does the screen show?
`timescale 1ns/1ps
module tb_chip_top (
);
    // To get 100ns button push:
    // f_clk = 100MHz, 
    // I want the ticks to have T_tick=10ns so button hold needs to count to 10
    // f_clk * T_tick = 1 -> tick_gen generates a tick every clk cycle.
    // f_tick = 100MHz, T_count = 10ns -> f_tick*T_count = 10 -> btn_hold needs to count to 10 to get 100ns btn hold.
    // But MAX_TICK cannot be 1 because it breakes tick_gen.v so make it 2.
    // => MAX_COUNT = 5;
    localparam MAX_TICK = 2;
    localparam MAX_COUNT = 5;
    
    localparam BCD_CALCULATION_TIME = 16;
    localparam SYNC_TIME = 2;

    localparam ROTATION = 5 * MAX_TICK;

    localparam ONE_SEC_CYCLES = MAX_TICK * MAX_COUNT;
    localparam LONG_PRESS = 2 * ONE_SEC_CYCLES;
    localparam SHORT_PRESS = 3;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n;
    reg [15:0] sw;
    reg btnc, btnd;
    wire dp;
    wire [6:0] ss_dig;
    wire [7:0] disp_an;

    integer pass = 0, fail = 0;

    chip_top #(.MAX_TICK(MAX_TICK), .MAX_COUNT(MAX_COUNT)) chip_top_i(clk, reset_n, sw, btnc, btnd, dp, ss_dig, disp_an);

    // Always block to check the digit in display i is correct;
    reg [4:0] ss_dig_on_display [7:0];
    reg display_on_off [7:0];
    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 8; i = i + 1) begin // loop throug all the screens and check witch one is on
            if (disp_an[i] == 0) begin // specific display is on
                ss_dig_on_display[i] <= ss2dig(ss_dig);
                display_on_off[i] <= 1;
            end
        end
    end

    integer j;
    task clear_display_vals();
        begin
            for (j = 0 ; j < 8; j = j + 1) begin
                ss_dig_on_display[j] = 5'b11111;
                display_on_off[j] = 0;
            end
        end
    endtask

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

    task wait_posedge();
        begin
            @(posedge clk); #1;
        end
    endtask


    task drive_btn (input btn_c, input btn_d, input integer hold_time);
        begin
            btnc = btn_c; btnd = btn_d;
            repeat (hold_time) wait_posedge();

            btnc = 0; btnd = 0;
            repeat (BCD_CALCULATION_TIME + SYNC_TIME) wait_posedge(); // need to wait for button to sync + 16 cycles of Double Dabble calculation

            clear_display_vals();
            repeat (2 * ROTATION) wait_posedge();
        end
    endtask

    task drive_sw (input [15:0] sw_val);
        begin
            sw = sw_val;
        end
    endtask

    task check_display_val(input exp_dec_hex, input [15:0] exp_value);
        reg [19:0] exp_digits;
        reg [7:0] res;
        integer i;
        begin
            res = 8'b0;
            if (reset_n) begin
                exp_digits = (exp_dec_hex) ? bin2bcd(exp_value) : {4'b0, exp_value};
                for (i = 0; i < 8; i = i + 1) begin
                    if (i >= 0 && i <=3) begin
                        if (display_on_off[i] && ss_dig_on_display[i] === {1'b0, exp_digits[4*i +: 4]}) 
                            res[i] = 1'b1;
                    end else if (i == 4) begin
                        if (exp_dec_hex) begin
                            if (display_on_off[i] && ss_dig_on_display[i] === {1'b0, exp_digits[4*i +: 4]})
                                res[i] = 1'b1;
                        end else begin
                            if (!display_on_off[i])
                                res[i] = 1'b1;
                        end
                    end
                    else begin
                        if (!display_on_off[i])
                            res[i] = 1'b1;
                    end

                    if (i >= 5 || (i == 4 && !exp_dec_hex)) begin
                        $display("Time: %5d | Check display %0d is off | actual=%s | exp=%s | %s", $time, i, res[i] ? "OFF" : "ON", "OFF", res[i] ? "PASS" : "FAIL");
                        if (res[i]) pass = pass + 1;
                        else fail = fail + 1;
                    end else begin
                        $display ("Time: %5d | Check display %0d | actual=%0h | expected=%0h | %s", $time, i, ss_dig_on_display[i], exp_digits[4*i +: 4], res[i] ? "PASS" : "FAIL");
                        if (res[i]) pass = pass + 1;
                        else fail = fail + 1;
                    end
                end

                $display("Time: %5d | Check dp is off | actual=%b | expected=%b | %s", $time, dp, 1'b1, (dp === 1'b1) ? "PASS" : "FAIL");
                if (dp === 1'b1) pass = pass + 1;
                else fail = fail + 1;
            end
        end
    endtask

    task reset();
        begin
            reset_n = 1'b0; btnc = 1'b0; btnd = 1'b0; sw = 16'b0;
            repeat (5) wait_posedge();

            reset_n = 1'b1;
            repeat (5) wait_posedge();

            clear_display_vals();
            repeat (2 * ROTATION) wait_posedge();
        end
    endtask

    integer k;
    reg [15:0] rand_val;
    initial begin
        reset();
        check_display_val(0, 16'd0);

        drive_sw(16'd12345);
        drive_btn(1, 0, LONG_PRESS);
        check_display_val(1, 16'd12345);

        drive_sw(16'd777);
        drive_btn(0, 0, LONG_PRESS);
        check_display_val(1, 16'd12345);

        drive_btn(0, 1, LONG_PRESS);
        check_display_val(0, 16'd777);

        drive_sw(16'd1);
        drive_btn(1, 0, SHORT_PRESS);
        check_display_val(0, 16'd777);

        drive_sw(16'd65535);
        drive_btn(1, 0, LONG_PRESS);
        check_display_val(1, 16'd65535);

        drive_btn(0, 1, LONG_PRESS);
        check_display_val(0, 16'hFFFF);

        drive_sw(16'd0);
        drive_btn(1, 0, LONG_PRESS);
        check_display_val(1, 16'd0);

        drive_sw(16'hABCD);
        drive_btn(1, 1, LONG_PRESS);
        check_display_val(0, 16'hABCD);

        drive_sw(16'd4321);
        drive_btn(1, 0, LONG_PRESS);
        check_display_val(1, 16'd4321);
        reset();
        check_display_val(0, 16'd0);

        for (k = 0; k < 10; k = k + 1) begin
            rand_val = $urandom;
            drive_sw(rand_val);
            if (k % 2) begin
                drive_btn(1, 0, LONG_PRESS);
                check_display_val(1, rand_val);
            end else begin
                drive_btn(0, 1, LONG_PRESS);
                check_display_val(0, rand_val);
            end
        end

        if (fail == 0 && pass > 0) $display("Time: %5d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %5d | TEST FAIL | %0d/%0d", $time, fail, pass + fail);

        $finish();
    end
endmodule
