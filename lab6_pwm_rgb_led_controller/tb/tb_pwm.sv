import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_pwm;
    timeunit 1ns;
    timeprecision 1ps;
    bit clk = '0;
    always #5 clk = !clk;

    localparam SLOTS_WIDTH = $clog2(`SLOTS);

    logic reset_n = '0;
    logic [SLOTS_WIDTH-1:0] value = '0;
    logic pwm_signal;


    pwm #(.SLOTS(`SLOTS)) dut (
        .clk(clk),
        .reset_n(reset_n),
        .value(value),
        .pwm_signal(pwm_signal)
    );

    logic [SLOTS_WIDTH:0] pwm_one_cnt;
    logic [SLOTS_WIDTH:0] pwm_zero_cnt;
    logic [SLOTS_WIDTH-1:0] pwm_cnt;
    bit last_cycle; assign last_cycle = (pwm_cnt == SLOTS_WIDTH'(`SLOTS - 1));
    bit new_cycle; assign new_cycle = (pwm_cnt == '0);
    always_ff @(posedge clk) begin
        if (!reset_n | last_cycle) pwm_cnt <= '0;
        else pwm_cnt <= pwm_cnt + 1;
    end
    always_ff @(posedge clk) begin
        if (!reset_n) pwm_one_cnt <= '0;
        else if (new_cycle) pwm_one_cnt <= pwm_signal;
        else if ((pwm_signal == '1)) pwm_one_cnt <= pwm_one_cnt + 1;
    end
    always_ff @(posedge clk) begin
        if (!reset_n) pwm_zero_cnt <= '0;
        else if (new_cycle) pwm_zero_cnt <= !pwm_signal;
        else if ((pwm_signal == '0)) pwm_zero_cnt <= pwm_zero_cnt + 1;
    end

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        reset_n = '1;
    endtask

    task wait_cycle();
        $display("Time: %0t | TASK: Waiting for new cycle to start", $time);
        while (!last_cycle) #(CLK_PERIOD); #(CLK_PERIOD);
    endtask

    task drive_value(input [SLOTS_WIDTH-1:0] val);
        $display("Time: %0t | TASK: Drive value: %d to pwm", $time, val); 
        while (!last_cycle) #(CLK_PERIOD);
        value = val;
        check_pwm_signal();    
    endtask

    task check_pwm_signal();
        $display("Time: %0t | TASK: Checking PWM signal", $time);
        wait_cycle();
        wait_cycle();
        $display("Time: %0t | pwm_one_count=%d | value=%d", $time, pwm_one_cnt, value);
        assert(pwm_one_cnt === value);
        assert(pwm_zero_cnt === `SLOTS - value);
    endtask

    initial begin
        reset_dut();
        drive_value(SLOTS_WIDTH'(`SLOTS / 2));
        drive_value('0);
        drive_value(SLOTS_WIDTH'(`SLOTS - 1));

        #(CLK_PERIOD); $finish;
    end


endmodule
