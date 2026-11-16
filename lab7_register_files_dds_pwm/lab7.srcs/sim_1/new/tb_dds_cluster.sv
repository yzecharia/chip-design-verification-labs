import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;

module tb_dds_cluster;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic wrap_red, wrap_green, wrap_blue;
    pwm_ctrl_t red_pwm_ctrl, green_pwm_ctrl, blue_pwm_ctrl;
    led_pattern_t pattern;
    logic pattern_change;
    corrected_pixel_t dds_pixel;

    dds_cluster dut(
        .clk(clk),
        .reset_n(reset_n),
        .wrap_red(wrap_red),
        .wrap_green(wrap_green),
        .wrap_blue(wrap_blue),
        .red_pwm_ctrl(red_pwm_ctrl),
        .green_pwm_ctrl(green_pwm_ctrl),
        .blue_pwm_ctrl(blue_pwm_ctrl),
        .pattern(pattern),
        .pattern_change(pattern_change),
        .dds_pixel(dds_pixel)
    );

    typedef enum logic [1:0] {RED, GREEN, BLUE} color_t;
    logic [16:0] exp_acc [3];
    typedef struct packed {
        logic wrap_red, wrap_green, wrap_blue;
        logic pattern_change;
    } op_t;

    function logic[12:0] get_freq(input color_t color, input led_pattern_t ptrn);
        case(ptrn)
            STATIC: 
                case(color)
                    RED: return red_pwm_ctrl.freq;
                    GREEN: return green_pwm_ctrl.freq;
                    BLUE: return blue_pwm_ctrl.freq;
                    default: return 'x; 
                endcase
            RAINBOW, BREATH: return red_pwm_ctrl.freq;
            default: return '0;
        endcase
    endfunction

    function logic [8:0] get_phase(input color_t color, input led_pattern_t ptrn);
        case(ptrn)
            STATIC: 
                case(color)
                    RED: return red_pwm_ctrl.phase;
                    GREEN: return green_pwm_ctrl.phase;
                    BLUE: return blue_pwm_ctrl.phase;
                    default: return 'x;
                endcase
            RAINBOW: 
                case(color)
                    RED: return 9'd0;
                    GREEN: return 9'd171;
                    BLUE: return 9'd341;
                    default: return 'x;
                endcase
            BREATH: return red_pwm_ctrl.phase;
            default: return '0;
        endcase
    endfunction

    function logic get_wrap(input color_t color, input led_pattern_t ptrn, input op_t op);
        case(ptrn)
            STATIC: 
                case(color)
                    RED: return op.wrap_red;
                    GREEN: return op.wrap_green;
                    BLUE: return op.wrap_blue;
                    default: return 'x;
                endcase
            RAINBOW, BREATH: return op.wrap_red;
            default: return '0;
        endcase
    endfunction

    function automatic logic [9:0] calc_table_val(input logic[8:0] i);
        localparam real PI = 3.14159265358979323846;
        real angle;
        real exact_val;
        int rounded_val;

        angle = (2.0 * PI * real'(i) / 512.0) - (PI / 2.0);
        exact_val = 1023.0 * ((1.0 + $sin(angle)) / 2.0);
        rounded_val = int'(exact_val);

        return 10'(rounded_val);
    endfunction

    function automatic logic [GAMMA_WIDTH-1:0] calc_exp_val(input logic[16:0] acc, input logic [1:0] mag);
        int temp;
        temp = calc_table_val(acc[16:8]) * (2**int'(mag));
        return (temp > 1023) ? GAMMA_WIDTH'(1023) : GAMMA_WIDTH'(temp);
    endfunction

    task reset_dut();
        reset_n = '0;
        {wrap_red, wrap_green, wrap_blue} = '0;
        {red_pwm_ctrl, green_pwm_ctrl, blue_pwm_ctrl} = '0;
        {pattern, pattern_change} = '0;
        exp_acc = '{default: '0};

        repeat(3) @(posedge clk);
        assert(dds_pixel === '0) else $error("Time: %0t | ERROR: Invalid dds_pixel reset value | actual=%p | expected=0", $time, dds_pixel);
        reset_n <= '1;
    endtask

    task set_config(input color_t clr, input pwm_ctrl_t ctrl, input led_pattern_t ptrn);
        @(posedge clk);
        case(clr)
            RED: red_pwm_ctrl <= ctrl;
            GREEN: green_pwm_ctrl <= ctrl;
            BLUE: blue_pwm_ctrl <= ctrl;
        endcase
        pattern <= ptrn;
        @(posedge clk);
    endtask

    task update_exp_acc(input color_t clr, input op_t op);
        if (op.pattern_change) exp_acc[clr] = {get_phase(clr, pattern), 8'h0};
        else if (get_wrap(clr, pattern, op)) exp_acc[clr] = exp_acc[clr] + get_freq(clr, pattern);
    endtask

    task drive(input op_t op);
        @(posedge clk);
        {wrap_red, wrap_green, wrap_blue, pattern_change} <= op;
        @(posedge clk);
        {wrap_red, wrap_green, wrap_blue, pattern_change} <= '0;
        update_exp_acc(RED, op);
        update_exp_acc(GREEN, op);
        update_exp_acc(BLUE, op);
        @(negedge clk);
        assert(dds_pixel.red === calc_exp_val(exp_acc[RED], red_pwm_ctrl.mag)) else $error("Time: %0t | ERROR: Invalid dds_pixel.red | op=%p | actual=%0d | expected=%0d", $time, op, dds_pixel.red, calc_exp_val(exp_acc[RED], red_pwm_ctrl.mag));
        assert(dds_pixel.green === calc_exp_val(exp_acc[GREEN], green_pwm_ctrl.mag)) else $error("Time: %0t | ERROR: Invalid dds_pixel.green | op=%p | actual=%0d | expected=%0d", $time, op, dds_pixel.green, calc_exp_val(exp_acc[GREEN], green_pwm_ctrl.mag));
        assert(dds_pixel.blue === calc_exp_val(exp_acc[BLUE], blue_pwm_ctrl.mag)) else $error("Time: %0t | ERROR: Invalid dds_pixel.blue | op=%p | actual=%0d | expected=%0d", $time, op, dds_pixel.blue, calc_exp_val(exp_acc[BLUE], blue_pwm_ctrl.mag));
    endtask

    initial begin
        reset_dut();
        set_config(RED, '{freq: 256, mag: 0, phase: 64}, BREATH);
        set_config(GREEN, '{freq: 512, mag: 0, phase: 128}, BREATH);
        set_config(BLUE, '{freq: 768, mag: 0, phase: 300}, BREATH);
        drive(4'b0001);

        repeat(2) drive(4'b1000);
        drive(4'b0100);
        drive(4'b0010);

        set_config(RED, red_pwm_ctrl, RAINBOW);
        drive(4'b0001);
        drive(4'b1000);

        repeat(170) drive(4'b1000);

        set_config(RED, red_pwm_ctrl, STATIC);
        drive(4'b0001);
        drive(4'b0100);
        drive(4'b0010);
        drive(4'b1110);

        $finish;
    end

endmodule
