import lab7_pkg::*;
import pwm_rgf_pkg::*;
module scale_cluster (
    input corrected_pixel_t [1:0] led_val,
    input pwm_cfg_t pwm_cfg,
    output scaled_val_t [1:0] scaled_vals
);  

genvar i;
generate
    for (i = 0; i < 2; i++) begin : scale_cluster_loop
        scaler scaler_i (
            .led_mux_val(led_val[i]),
            .pwm_cfg(pwm_cfg),
            .scaled_vals(scaled_vals[i])
        );
    end
endgenerate


endmodule
