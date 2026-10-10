`timescale 1ns/1ps
module tb_value_latch (
);

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n, pressed_c, pressed_d;
    reg [15:0] sw;

    wire pressed = pressed_c | pressed_d;

    wire dec_hex;
    wire [15:0] sw_reg;

    reg [15:0] exp_sw;
    reg exp_dec_hex;

    integer pass = 0, fail = 0;

    value_latch value_latch_i (clk, reset_n, pressed_c, pressed_d, sw, dec_hex, sw_reg);

    task wait_posedge();
        begin
            @(posedge clk); #1;
        end
    endtask

    task reset();
        begin
            reset_n = 1'b0; pressed_c = 1'b0; pressed_d = 1'b0; sw = 16'b0;
            repeat (1) wait_posedge();

            reset_n = 1'b1;
        end
    endtask

    task check_value(input exp_dec_hex, input [15:0] exp_sw);
        reg res;
        begin
            res = (exp_dec_hex == dec_hex) && (exp_sw == sw_reg);
            $display("Time: %5d | dec_hex=%b exp=%b | sw_reg=%h exp=%h | %s", $time, dec_hex, exp_dec_hex, sw_reg, exp_sw, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    task drive_values(input press_c, input press_d, input [15:0] sw_val);
        begin
            pressed_c = press_c;
            pressed_d = press_d;
            sw = sw_val;
            wait_posedge();
        end
    endtask

    initial begin
        reset(); check_value(0, 16'b0);
        drive_values(0, 0, 16'h1234); check_value(0, 16'b0);
        drive_values(1, 0, 16'h1234); check_value(1, 16'h1234);
        drive_values(0, 1, 16'h5678); check_value(0, 16'h5678);
        drive_values(0, 0, 16'hABBA); check_value(0, 16'h5678);
        drive_values(1, 1, 16'hFFFF); check_value(0, 16'hFFFF); 
        wait_posedge();

        if(fail == 0 & pass > 0) $display("Time: %5d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %5d | TEST FAIL | %0d/%0d", $time, pass, pass + fail);

        $finish();
    end

    


endmodule
