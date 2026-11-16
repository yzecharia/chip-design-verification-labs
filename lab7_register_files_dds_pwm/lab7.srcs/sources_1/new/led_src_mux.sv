import lab7_pkg::*;
import led_rgf_pkg::*;
import pwm_rgf_pkg::*;
module led_src_mux (
    input logic clk, reset_n,
    input led_value_t led16, led17,
    input logic wrap_cnt, // can be any one of the 3 they all finish at the same time
    input pwm_rgf_msg_t pwm_msg,
    input led_pattern_t pattern,
    input logic pattern_change,
    input led_ctrl_t led_ctrl,
    output corrected_pixel_t [1:0] led_val
);


corrected_pixel_t led16_gemma, led17_gemma;
gemma_correction_cluster gemma_clust_i (
    .led16(led16),
    .led17(led17),
    .led16_gemma(led16_gemma),
    .led17_gemma(led17_gemma)
);

corrected_pixel_t led16_cie, led17_cie;
cie_scaling_cluster cie_clust_i (
    .led16_gemma(led16_gemma),
    .led17_gemma(led17_gemma),
    .led16_cie(led16_cie),
    .led17_cie(led17_cie)
);

corrected_pixel_t dds_pixel;
dds_cluster dds_clust_i (
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
    .dds_pixel(dds_pixel)
);


always_comb begin : led16_mux
    if (!led_ctrl.led16_power) led_val[0] = '0;
    else if ((pattern == BREATH) | (pattern == RAINBOW)) led_val[0] = dds_pixel;
    else begin
        led_val[0] = (led_ctrl.led16_cie) ? led16_cie : led16_gemma;
    end 
end

always_comb begin : led17_mux
    if (!led_ctrl.led17_power) led_val[1] = '0;
    else if ((pattern == BREATH) | (pattern == RAINBOW)) led_val[1] = dds_pixel;
    else begin
        led_val[1] = (led_ctrl.led17_cie) ? led17_cie : led17_gemma;
    end 
end
endmodule
