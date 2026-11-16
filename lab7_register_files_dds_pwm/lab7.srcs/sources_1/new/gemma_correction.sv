import lab7_pkg::*;
import led_rgf_pkg::*;
module gemma_correction(
    input led_value_t pixel_in,
    output corrected_pixel_t pixel_out
);  
    `include "black_magic_box.sv"
    assign pixel_out.red = gamma_table[pixel_in.red];
    assign pixel_out.green = gamma_table[pixel_in.green];
    assign pixel_out.blue = gamma_table[pixel_in.blue];
endmodule
