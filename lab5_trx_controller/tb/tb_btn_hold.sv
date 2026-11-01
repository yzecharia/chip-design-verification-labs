`include "lab5_definitions.svh"
module tb_btn_hold;
    timeunit 1ns;
    timeprecision 1ps;
    import lab5_pkg::*;

    localparam BTN_HOLD_WAIT = (`BTN_HOLD_COUNT) * 10;

    bit clk = '0;
    always #5 clk =!clk;

    logic reset_n;
    logic btn = '0;
    logic held;

    btn_hold #(.BTN_HOLD_COUNT(`BTN_HOLD_COUNT)) btn_hold_i (
        .clk(clk),
        .reset_n(reset_n),
        .btn(btn),
        .held(held)
    );

    initial $monitor("Time: %0t | btn=%0b | held=%0b", $time, btn, held);

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD); assert(!held);
        reset_n = '1; 
    endtask

    task press_button(input int press_time, input bit release_press);
        $display("Time: %0t | TASK: Press button", $time);
        btn = '1; #(press_time);
        if (press_time == (BTN_HOLD_WAIT)) assert(held);
        else assert(!held); #(CLK_PERIOD);
        if (release_press) begin
            $display("Time: %0t | TASK: Release button press", $time);
            btn = '0; #(CLK_PERIOD);
        end
    endtask

    initial begin
        reset_dut();

        $display("Time: %0t | Regular press", $time);
        press_button(BTN_HOLD_WAIT, '1);

        $display("Time: %0t | Short press", $time);
        press_button(BTN_HOLD_WAIT/2, '1);

        $display("Time: %0t | Long press", $time);
        press_button(BTN_HOLD_WAIT * 2, '1);

        $display("Time: %0t | Reset mid press", $time);
        press_button(BTN_HOLD_WAIT/2, '0);
        reset_dut();
        press_button(BTN_HOLD_WAIT, '1);


        $finish;
    end


    // Functionality:
    // 1. btn pressed for BTN_HOLD_COUNT cycles => held = '1;
    // 2. if btn is pressed for period > BTN_HOLD_WAIT then only one held pulse should be recorded
    // 3. held is a one pulse signal

    // 1. 

    int count_press;
    always @(posedge clk) begin
        if (!reset_n | !btn) count_press <= '0;
        else if (btn) count_press <= count_press + 1;
    end

    bit valid_press; assign valid_press = (count_press == `BTN_HOLD_COUNT);

    property p_held_after_count;
        @(posedge clk)
        disable iff (!reset_n)
        (valid_press) |-> held;
    endproperty

    // 2. 
    int count_held;
    always_ff @(posedge clk) begin
        if (!reset_n | !btn) count_held <= '0;
        else if (held) count_held <= count_held + 1;  
    end

    bit one_held; assign one_held = (count_held == 1);

    property p_held_once_per_btn;
        @(posedge clk)
        disable iff (!reset_n)
        (count_press > `BTN_HOLD_COUNT) |-> (one_held);
    endproperty

    // 3.
    property p_held_one_cycle;
        @(posedge clk)
        disable iff(!reset_n)
        ($past(held)) |-> (!held);
    endproperty 

    assert property(p_held_after_count);
    assert property(p_held_once_per_btn);
    assert property(p_held_one_cycle);


endmodule
