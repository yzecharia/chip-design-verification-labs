import lab6_pkg::*;

module gemma_correction(
    input pixel_parsed_t pixel_in,
    output corrected_pixel_t pixel_out
);  
    `include "black_magic_box.sv"
    assign pixel_out.red = gamma_table[pixel_in.value_2];
    assign pixel_out.green = gamma_table[pixel_in.value_1];
    assign pixel_out.blue = gamma_table[pixel_in.value_0];
endmodule
