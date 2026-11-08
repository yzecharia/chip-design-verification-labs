import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_selector;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    btn_ctf_t btn_in = '0;
    pixel_parsed_t parsed_pixel_value = '0;
    logic parsed_led_value = '0;
    logic pixel_valid = '0;
    logic led_valid = '0;
    pixel_parsed_t display_pixel, pwm_pixel;
    logic pwm_new_data, pwm_led, display_led;
    leds_cfg_t leds_out;

    selector dut (
        .clk(clk),
        .reset_n(reset_n),
        .btn_in(btn_in),
        .parsed_pixel_value(parsed_pixel_value),
        .parsed_led_value(parsed_led_value),
        .pixel_valid(pixel_valid),
        .led_valid(led_valid),
        .display_pixel(display_pixel),
        .pwm_pixel(pwm_pixel),
        .pwm_new_data(pwm_new_data),
        .pwm_led(pwm_led),
        .display_led(display_led),
        .leds_out(leds_out)
    );

    localparam leds_cfg_t T0_LEDS = 16'h0030;
    localparam leds_cfg_t T1_LEDS = 16'h0180;
    localparam leds_cfg_t T2_LEDS = 16'h0600;
    localparam leds_cfg_t T3_LEDS = 16'h3000;

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(display_pixel === '0) else $error("display_pixel = %h after reset", display_pixel);
        assert(pwm_pixel === '0) else $error("pwm_pixel = %h after reset", pwm_pixel);
        assert(display_led === '0) else $error("display_led = %b after reset", display_led);
        assert(pwm_led === '0) else $error("pwm_led = %b after reset", pwm_led);
        assert(pwm_new_data === '0) else $error("pwm_new_data = %b after reset", pwm_new_data);
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

    task send_pixel(input pixel_parsed_t p);
        $display("Time: %0t | TASK: UART pixel %h", $time, p);
        parsed_pixel_value = p; pixel_valid = '1; #(CLK_PERIOD);
        pixel_valid = '0;
        assert(pwm_new_data === '1) else $error("pwm_new_data = %b after pixel_valid, expected 1", pwm_new_data);
        #(CLK_PERIOD);
        assert(pwm_new_data === '0) else $error("pwm_new_data = %b, expected a one cycle pulse", pwm_new_data);
    endtask

    task send_led(input logic l);
        $display("Time: %0t | TASK: UART led %b", $time, l);
        parsed_led_value = l; led_valid = '1; #(CLK_PERIOD);
        led_valid = '0; #(CLK_PERIOD);
    endtask

    task check_pixels(input pixel_parsed_t exp_display, input pixel_parsed_t exp_pwm);
        assert(display_pixel === exp_display) else $error("display_pixel = %h, expected %h", display_pixel, exp_display);
        assert(pwm_pixel === exp_pwm) else $error("pwm_pixel = %h, expected %h", pwm_pixel, exp_pwm);
    endtask

    task check_leds(input logic exp_display, input logic exp_pwm);
        assert(display_led === exp_display) else $error("display_led = %b, expected %b", display_led, exp_display);
        assert(pwm_led === exp_pwm) else $error("pwm_led = %b, expected %b", pwm_led, exp_pwm);
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

        // 1. UART pixel loads both copies
        send_pixel(24'h10_20_30);
        check_pixels(24'h10_20_30, 24'h10_20_30);

        // 2. up on T0 (blue): only display changes, no pwm_new_data
        press(UP);
        check_pixels(24'h10_20_31, 24'h10_20_30);
        assert(pwm_new_data === '0) else $error("pwm_new_data = 1 after up");

        // 3. cursor walks left T0 -> T3 and stops there
        press(LEFT); check_cursor(T1_LEDS);
        press(UP);   check_pixels(24'h10_21_31, 24'h10_20_30);
        press(LEFT); check_cursor(T2_LEDS);
        press(DOWN); check_pixels(24'h0F_21_31, 24'h10_20_30);
        press(LEFT); check_cursor(T3_LEDS);
        press(LEFT); check_cursor(T3_LEDS);

        // 4. led field: up -> 1, up again stays 1, down -> 0
        press(UP);   check_leds('1, '0);
        press(UP);   check_leds('1, '0);
        press(DOWN); check_leds('0, '0);
        press(UP);   check_leds('1, '0);

        // 5. center copies display -> pwm, with a pwm_new_data pulse
        btn_in = CENTER; #(CLK_PERIOD);
        btn_in = '0;
        assert(pwm_new_data === '1) else $error("pwm_new_data = %b after center, expected 1", pwm_new_data);
        #(CLK_PERIOD);
        assert(pwm_new_data === '0) else $error("pwm_new_data = %b, expected a one cycle pulse", pwm_new_data);
        check_pixels(24'h0F_21_31, 24'h0F_21_31);
        check_leds('1, '1);

        // 6. cursor walks right T3 -> T0 and stops there
        press(RIGHT); press(RIGHT); press(RIGHT); check_cursor(T0_LEDS);
        press(RIGHT); check_cursor(T0_LEDS);

        // 7. saturation: 255 + 1 stays 255, 0 - 1 stays 0
        send_pixel(24'hFF_00_FF);
        press(UP);   check_pixels(24'hFF_00_FF, 24'hFF_00_FF);
        press(LEFT); press(DOWN); check_pixels(24'hFF_00_FF, 24'hFF_00_FF);
        press(LEFT); press(UP);   check_pixels(24'hFF_00_FF, 24'hFF_00_FF);

        // 8. holding a button is one step (edge detect)
        press(DOWN); check_pixels(24'hFE_00_FF, 24'hFF_00_FF);
        hold(DOWN, 10); check_pixels(24'hFD_00_FF, 24'hFF_00_FF);

        // 9. UART led loads both copies, no pwm_new_data
        send_led('0);
        check_leds('0, '0);
        assert(pwm_new_data === '0) else $error("pwm_new_data = 1 after led_valid");

        #(CLK_PERIOD); $finish;
    end

endmodule
