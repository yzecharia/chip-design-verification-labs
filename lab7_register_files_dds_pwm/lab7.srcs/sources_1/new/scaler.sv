import lab7_pkg::*;
import pwm_rgf_pkg::*;
module scaler (
    input corrected_pixel_t led_mux_val,
    input pwm_cfg_t pwm_cfg,
    output scaled_val_t scaled_vals
);

    /*
        say val is 512 in scal of gamma width (1024)
        then if i want to change to a different scale i need to do
        512/1024 * 100 = 50 (and 50 is 512 in 100 scale)
    */


logic [2:0][GAMMA_WIDTH-1:0] led_vals; assign led_vals = led_mux_val;
logic [2:0][GAMMA_WIDTH + TIME_SLOTS_WIDTH - 1:0] led_vals_mul;

localparam SCALE_IN = 1024;
localparam SCALE_IN_WIDTH = $clog2(SCALE_IN);

genvar i;
generate
    for(i = 0; i < 3; i++) begin : scale_loop
        assign led_vals_mul[i] = led_vals[i];
        assign scaled_vals[i] = (led_vals_mul[i] * pwm_cfg.sweep_time) >> SCALE_IN_WIDTH;
    end
endgenerate


endmodule
