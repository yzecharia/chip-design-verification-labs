import lab7_pkg::*;
module cie_scaling(
    input corrected_pixel_t pixel_in,
    output corrected_pixel_t pixel_out
);

    assign pixel_out.red = pixel_in.red;
    assign pixel_out.green = (pixel_in.green >> 1) + (pixel_in.green >> 7);
    assign pixel_out.blue = pixel_in.blue;

endmodule
