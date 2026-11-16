import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;

module dds_cluster (
    input logic clk, reset_n,
    input logic wrap_red, wrap_green, wrap_blue,
    input pwm_ctrl_t red_pwm_ctrl, green_pwm_ctrl, blue_pwm_ctrl,
    input led_pattern_t pattern,
    input logic pattern_change,
    output corrected_pixel_t dds_pixel
);

    logic [2:0][8:0] phase_comb;
    always_comb begin : phase_dec
        unique case(pattern)
            STATIC: phase_comb = {red_pwm_ctrl.phase, green_pwm_ctrl.phase, blue_pwm_ctrl.phase};
            RAINBOW: phase_comb = {RAINBOW_RED_PHASE, RAINBOW_GREEN_PHASE, RAINBOW_BLUE_PHASE};
            BREATH: phase_comb = {3{red_pwm_ctrl.phase}};
            INVALID: phase_comb = '0;
            default: phase_comb = '0;
        endcase
    end

    logic [2:0][12:0] freq_comb;
    always_comb begin : frew_dec
        unique case(pattern)
            STATIC: freq_comb = {red_pwm_ctrl.freq, green_pwm_ctrl.freq, blue_pwm_ctrl.freq};
            RAINBOW, BREATH: freq_comb = {3{red_pwm_ctrl.freq}};
            INVALID: freq_comb = '0;
            default: freq_comb = '0; 
        endcase
    end


    logic [2:0] wrap_comb;
    always_comb begin : wrap_dec
        unique case(pattern)
            STATIC: wrap_comb = {wrap_red, wrap_green, wrap_blue};
            RAINBOW, BREATH: wrap_comb = {3{wrap_red}};
            INVALID: wrap_comb = '0;
            default: wrap_comb = '0;
        endcase
    end

    
    dds_single_ch dds_red_ch (
        .clk(clk),
        .reset_n(reset_n),
        .cnt_wrap(wrap_comb[2]),
        .pwm_ch_ctrl({freq_comb[2], red_pwm_ctrl.mag, phase_comb[2]}),
        .pattern_change(pattern_change),
        .dds_ch_val(dds_pixel.red)
    );

    dds_single_ch dds_green_ch (
        .clk(clk),
        .reset_n(reset_n),
        .cnt_wrap(wrap_comb[1]),
        .pwm_ch_ctrl({freq_comb[1], green_pwm_ctrl.mag, phase_comb[1]}),
        .pattern_change(pattern_change),
        .dds_ch_val(dds_pixel.green)
    );

    dds_single_ch dds_blue_ch (
        .clk(clk),
        .reset_n(reset_n),
        .cnt_wrap(wrap_comb[0]),
        .pwm_ch_ctrl({freq_comb[0], blue_pwm_ctrl.mag, phase_comb[0]}),
        .pattern_change(pattern_change),
        .dds_ch_val(dds_pixel.blue)
    );



endmodule
