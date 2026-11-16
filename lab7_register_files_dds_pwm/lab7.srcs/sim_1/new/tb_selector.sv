import lab7_pkg::*;
import led_rgf_pkg::*;
`include "lab7_definitions.svh"

module tb_selector;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    btn_ctf_t btn_in = '0;
    led_rgf_msg_t led_rgf_msg;
    logic pc_led_update = '0;
    leds_cfg_t leds_out;
    selector_data_t sel_out;

    selector dut (
        .clk(clk),
        .reset_n(reset_n),
        .btn_in(btn_in),
        .led_rgf_msg(led_rgf_msg),
        .pc_led_update(pc_led_update),
        .leds_out(leds_out),
        .sel_out(sel_out)
    );

    localparam leds_cfg_t T0_LEDS = 16'h0030;
    localparam leds_cfg_t T1_LEDS = 16'h0180;
    localparam leds_cfg_t T2_LEDS = 16'h0600;
    localparam leds_cfg_t T3_LEDS = 16'h3000;

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        led_rgf_msg = '0;
        reset_n = '0; #(CLK_PERIOD);
        assert(sel_out.led_value === '0) else $error("sel_out.led_value = %h after reset", sel_out.led_value);
        assert(sel_out.display_led === '0) else $error("sel_out.display_led = %b after reset", sel_out.display_led);
        assert(sel_out.btnc === '0) else $error("sel_out.btnc = %b after reset", sel_out.btnc);
        assert(leds_out === T0_LEDS) else $error("leds_out = %h after reset, expected %h", leds_out, T0_LEDS);
        reset_n = '1;
    endtask

    // one press = level up for one clock, then back down (the edge detector inside makes one pulse)
    task press(input btn_ctf_t b);
        $display("Time: %0t | TASK: Press %b (up down left right center)", $time, b);
        btn_in = b; #(CLK_PERIOD);
        btn_in = '0; #(CLK_PERIOD);
    endtask

    task hold(input btn_ctf_t b, input int cycles);
        $display("Time: %0t | TASK: Hold %b for %0d cycles", $time, b, cycles);
        btn_in = b; #(CLK_PERIOD * cycles);
        btn_in = '0; #(CLK_PERIOD);
    endtask

    task send_pixel(input led_value_t p);
        $display("Time: %0t | TASK: led_rgf pixel %h", $time, p);
        led_rgf_msg.led_ctrl.select = LED16_SEL_VAL; led_rgf_msg.led16_value = p; pc_led_update = '1; #(CLK_PERIOD);
        pc_led_update = '0; #(CLK_PERIOD);
    endtask

    task send_led(input logic l);
        $display("Time: %0t | TASK: led_rgf led %b", $time, l);
        led_rgf_msg.led_ctrl.select = l ? LED17_SEL_VAL : LED16_SEL_VAL; pc_led_update = '1; #(CLK_PERIOD);
        pc_led_update = '0; #(CLK_PERIOD);
    endtask

    task check_pixel(input led_value_t exp_display);
        assert(sel_out.led_value === exp_display) else $error("sel_out.led_value = %h, expected %h", sel_out.led_value, exp_display);
    endtask

    task check_led(input logic exp_display);
        assert(sel_out.display_led === exp_display) else $error("sel_out.display_led = %b, expected %b", sel_out.display_led, exp_display);
    endtask

    task check_cursor(input leds_cfg_t exp);
        assert(leds_out === exp) else $error("leds_out = %h, expected %h", leds_out, exp);
    endtask

    btn_ctf_t UP     = '{up: 1, default: 0};
    btn_ctf_t DOWN   = '{down: 1, default: 0};
    btn_ctf_t LEFT   = '{left: 1, default: 0};
    btn_ctf_t RIGHT  = '{right: 1, default: 0};
    btn_ctf_t CENTER = '{center: 1, default: 0};

    initial begin
        reset_dut();

        // 1. led_rgf pixel loads the display copy
        send_pixel(24'h10_20_30);
        check_pixel(24'h10_20_30);

        // 2. up on T0 (blue): only display changes, no btnc
        press(UP);
        check_pixel(24'h10_20_31);
        assert(sel_out.btnc === '0) else $error("sel_out.btnc = 1 after up");

        // 3. cursor walks left T0 -> T3 and stops there
        press(LEFT); check_cursor(T1_LEDS);
        press(UP);   check_pixel(24'h10_21_31);
        press(LEFT); check_cursor(T2_LEDS);
        press(DOWN); check_pixel(24'h0F_21_31);
        press(LEFT); check_cursor(T3_LEDS);
        press(LEFT); check_cursor(T3_LEDS);

        // 4. led field: up -> 1, up again stays 1, down -> 0
        press(UP);   check_led('1);
        press(UP);   check_led('1);
        press(DOWN); check_led('0);
        press(UP);   check_led('1);

        // 5. center gives a one cycle btnc pulse, display stays
        btn_in = CENTER; #(CLK_PERIOD/2.0);
        assert(sel_out.btnc === '1) else $error("sel_out.btnc = %b after center, expected 1", sel_out.btnc);
        #(CLK_PERIOD/2.0);
        btn_in = '0;
        assert(sel_out.btnc === '0) else $error("sel_out.btnc = %b, expected a one cycle pulse", sel_out.btnc);
        #(CLK_PERIOD);
        check_pixel(24'h0F_21_31);
        check_led('1);

        // 6. cursor walks right T3 -> T0 and stops there
        press(RIGHT); press(RIGHT); press(RIGHT); check_cursor(T0_LEDS);
        press(RIGHT); check_cursor(T0_LEDS);

        // 7. saturation: 255 + 1 stays 255, 0 - 1 stays 0
        send_pixel(24'hFF_00_FF);
        press(UP);   check_pixel(24'hFF_00_FF);
        press(LEFT); press(DOWN); check_pixel(24'hFF_00_FF);
        press(LEFT); press(UP);   check_pixel(24'hFF_00_FF);

        // 8. holding a button is one step (edge detect)
        press(DOWN); check_pixel(24'hFE_00_FF);
        hold(DOWN, 10); check_pixel(24'hFD_00_FF);

        // 9. led_rgf led loads the display copy, no btnc
        send_led('1);
        check_led('1);
        check_pixel(24'h00_00_00);
        send_led('0);
        check_led('0);
        check_pixel(24'hFF_00_FF);
        assert(sel_out.btnc === '0) else $error("sel_out.btnc = 1 after pc_led_update");

        #(CLK_PERIOD); $finish;
    end

endmodule
