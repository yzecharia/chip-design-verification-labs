import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;

module pwm_led_cluster (
    input logic clk, reset_n,
    input pwm_cfg_t pwm_cfg,
    input scaled_val_t scaled_vals,
    output logic [CH_NUM-1:0] pwm_signals,
    output logic wrap_cnt
);

    genvar i;
    generate
        for (i = 0; i < CH_NUM; i++) begin : rgb_pwm_loop
            if (i == 0) begin
                pwm pwm_i (
                    .clk(clk),
                    .reset_n(reset_n),
                    .pwm_cfg(pwm_cfg),
                    .scaled_val(scaled_vals[i]),
                    .pwm_signal(pwm_signals[i]),
                    .wrap_cnt(wrap_cnt)
                );
            end else begin
                pwm pwm_i (
                    .clk(clk),
                    .reset_n(reset_n),
                    .pwm_cfg(pwm_cfg),
                    .scaled_val(scaled_vals[i]),
                    .pwm_signal(pwm_signals[i]),
                    .wrap_cnt()
                );
            end
        end
    endgenerate

   

endmodule
