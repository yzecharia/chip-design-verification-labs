import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;

module pwm_cluster (
    input logic clk, reset_n,
    input pwm_cfg_t pwm_cfg,
    input scaled_val_t [RGB_LED_NUM-1:0] scaled_vals,
    output logic [CH_NUM-1:0] pwm_signals_16, pwm_signals_17,
    output logic wrap_cnt 
);


    pwm_led_cluster pwm_led_16_i (
        .clk(clk),
        .reset_n(reset_n),
        .pwm_cfg(pwm_cfg),
        .scaled_vals(scaled_vals[0]),
        .pwm_signals(pwm_signals_16),
        .wrap_cnt(wrap_cnt)
    );


    pwm_led_cluster pwm_led_17_i (
        .clk(clk),
        .reset_n(reset_n),
        .pwm_cfg(pwm_cfg),
        .scaled_vals(scaled_vals[1]),
        .pwm_signals(pwm_signals_17),
        .wrap_cnt()
    );

endmodule
