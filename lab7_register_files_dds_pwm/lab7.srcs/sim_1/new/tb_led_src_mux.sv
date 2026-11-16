import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;


module tb_led_src_mux;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    led_value_t led16, led17;
    logic wrap_cnt;
    pwm_rgf_msg_t pwm_msg;
    led_pattern_t pattern;
    logic pattern_change;
    led_ctrl_t led_ctrl;
    corrected_pixel_t [1:0] led_val;

    led_src_mux dut(
        .clk(clk),
        .reset_n(reset_n),
        .led16(led16),
        .led17(led17),
        .wrap_cnt(wrap_cnt),
        .pwm_msg(pwm_msg),
        .pattern(pattern),
        .pattern_change(pattern_change),
        .led_ctrl(led_ctrl),
        .led_val(led_val)
    );

    corrected_pixel_t exp_led16_gemma, exp_led17_gemma;
    corrected_pixel_t exp_led16_cie, exp_led17_cie;
    corrected_pixel_t exp_dds_pixel;

    gemma_correction ref_led16_gemma(
        .pixel_in(led16),
        .pixel_out(exp_led16_gemma)
    );

    gemma_correction ref_led17_gemma(
        .pixel_in(led17),
        .pixel_out(exp_led17_gemma)
    );

    cie_scaling ref_led16_cie(
        .pixel_in(exp_led16_gemma),
        .pixel_out(exp_led16_cie)
    );

    cie_scaling ref_led17_cie(
        .pixel_in(exp_led17_gemma),
        .pixel_out(exp_led17_cie)
    );

    dds_cluster ref_dds(
        .clk(clk),
        .reset_n(reset_n),
        .wrap_red(wrap_cnt),
        .wrap_green(wrap_cnt),
        .wrap_blue(wrap_cnt),
        .red_pwm_ctrl(pwm_msg.red_ctrl),
        .green_pwm_ctrl(pwm_msg.green_ctrl),
        .blue_pwm_ctrl(pwm_msg.blue_ctrl),
        .pattern(pattern),
        .pattern_change(pattern_change),
        .dds_pixel(exp_dds_pixel)
    );

    typedef enum logic {LED16, LED17} led_t;
    typedef struct packed {
        logic wrap_cnt;
        logic pattern_change;
    } op_t;

    function logic get_power(input led_t led);
        case(led)
            LED16: return led_ctrl.led16_power;
            LED17: return led_ctrl.led17_power;
            default: return 'x;
        endcase
    endfunction

    function corrected_pixel_t get_static_val(input led_t led);
        case(led)
            LED16: return led_ctrl.led16_cie ? exp_led16_cie : exp_led16_gemma;
            LED17: return led_ctrl.led17_cie ? exp_led17_cie : exp_led17_gemma;
            default: return 'x;
        endcase
    endfunction

    function corrected_pixel_t exp_led(input led_t led);
        if (!get_power(led)) return '0;
        case(pattern)
            BREATH, RAINBOW: return exp_dds_pixel;
            default: return get_static_val(led);
        endcase
    endfunction

    task reset_dut();
        reset_n = '0;
        {led16, led17} = '0;
        {wrap_cnt, pattern_change} = '0;
        pwm_msg = '0;
        pattern = '0;
        led_ctrl = '0;

        repeat(3) @(posedge clk);
        assert(led_val === '0) else $error("Time: %0t | ERROR: Invalid led_val reset value | actual=%p | expected=0", $time, led_val);
        reset_n <= '1;
    endtask

    task check_led(input led_t led);
        assert(led_val[led].red === exp_led(led).red) else $error("Time: %0t | ERROR: Invalid led_val[%0d].red | pattern=%0d | led_ctrl=%b | actual=%0d | expected=%0d", $time, led, pattern, led_ctrl, led_val[led].red, exp_led(led).red);
        assert(led_val[led].green === exp_led(led).green) else $error("Time: %0t | ERROR: Invalid led_val[%0d].green | pattern=%0d | led_ctrl=%b | actual=%0d | expected=%0d", $time, led, pattern, led_ctrl, led_val[led].green, exp_led(led).green);
        assert(led_val[led].blue === exp_led(led).blue) else $error("Time: %0t | ERROR: Invalid led_val[%0d].blue | pattern=%0d | led_ctrl=%b | actual=%0d | expected=%0d", $time, led, pattern, led_ctrl, led_val[led].blue, exp_led(led).blue);
    endtask

    task set_leds(input led_value_t val16, input led_value_t val17);
        @(posedge clk);
        led16 <= val16;
        led17 <= val17;
        @(negedge clk);
        check_led(LED16);
        check_led(LED17);
    endtask

    task set_led_ctrl(input led_ctrl_t ctrl);
        @(posedge clk);
        led_ctrl <= ctrl;
        @(negedge clk);
        check_led(LED16);
        check_led(LED17);
    endtask

    task set_pattern(input led_pattern_t ptrn);
        @(posedge clk);
        pattern <= ptrn;
        @(negedge clk);
        check_led(LED16);
        check_led(LED17);
    endtask

    task set_pwm_msg(input pwm_ctrl_t red, input pwm_ctrl_t green, input pwm_ctrl_t blue);
        @(posedge clk);
        pwm_msg.red_ctrl <= red;
        pwm_msg.green_ctrl <= green;
        pwm_msg.blue_ctrl <= blue;
        @(negedge clk);
        check_led(LED16);
        check_led(LED17);
    endtask

    task drive(input op_t op);
        @(posedge clk);
        {wrap_cnt, pattern_change} <= op;
        @(posedge clk);
        {wrap_cnt, pattern_change} <= '0;
        @(negedge clk);
        check_led(LED16);
        check_led(LED17);
    endtask

    initial begin
        reset_dut();
        set_pwm_msg('{freq: 256, mag: 0, phase: 64}, '{freq: 512, mag: 0, phase: 128}, '{freq: 768, mag: 0, phase: 300});
        set_leds(24'hFF8040, 24'h00C8FF);
        set_led_ctrl('{led16_power: 1, led17_power: 1, default: 0});
        assert(led_val[LED16] === {10'd1023, 10'd221, 10'd52}) else $error("Time: %0t | ERROR: Invalid led_val[0] static value | actual=%p", $time, led_val[LED16]);
        assert(led_val[LED17] === {10'd0, 10'd591, 10'd1023}) else $error("Time: %0t | ERROR: Invalid led_val[1] static value | actual=%p", $time, led_val[LED17]);

        set_led_ctrl('{led16_power: 1, led17_power: 1, led16_cie: 1, default: 0});
        set_led_ctrl('{led16_power: 1, led17_power: 1, led17_cie: 1, default: 0});

        set_led_ctrl('{led17_power: 1, led16_cie: 1, led17_cie: 1, default: 0});
        set_led_ctrl('{led16_power: 1, led16_cie: 1, led17_cie: 1, default: 0});

        set_led_ctrl('{led16_power: 1, led17_power: 1, default: 0});
        set_pattern(BREATH);
        drive(2'b01);
        drive(2'b10);
        set_pattern(RAINBOW);
        drive(2'b01);
        assert(led_val[LED16] === {10'd0, 10'd769, 10'd769}) else $error("Time: %0t | ERROR: Invalid led_val[0] rainbow value | actual=%p", $time, led_val[LED16]);
        drive(2'b10);

        set_led_ctrl('{led16_power: 1, led17_power: 1, led16_cie: 1, led17_cie: 1, default: 0});
        set_led_ctrl('{led17_power: 1, default: 0});

        $finish;
    end

endmodule
