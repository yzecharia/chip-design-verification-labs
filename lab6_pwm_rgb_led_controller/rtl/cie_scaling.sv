import lab6_pkg::*;
`include "lab6_definitions.svh"
module cie_scaling #(
    parameter SLOTS = `SLOTS,
    localparam int SLOTS_WIDTH = $clog2(SLOTS)
)(
    input corrected_pixel_t pixel_in,
    output logic [2:0][SLOTS_WIDTH-1:0] pixel_out
);

    /*
        CIE / luminance scaling, normalized to RED (brightness over perfect balance).
        REC.601: Y = 0.299R + 0.587G + 0.114B  - the eye sees green ~2x red and ~5x blue.
        scale_c = 0.299 / weight_c

        1. Red:   1
        2. Green: 0.299/0.587 = 0.509 ~ 0.5078 = 1/2 + 1/128   (-0.3%)
        3. Blue:  0.299/0.114 = 2.62  -> cannot exceed 100% duty, clamped to 1
                  (blue stays ~2.6x weaker in perception than red/green; documented in the report)

        Example, SLOTS = 1024, input 1023:
        Red(255) = 1023, Green(255) = 518, Blue(255) = 1023
        Shifts and adds only, no multipliers.
    */
    typedef struct packed {
        logic [SLOTS_WIDTH-1:0] red;
        logic [SLOTS_WIDTH-1:0] green;
        logic [SLOTS_WIDTH-1:0] blue;

    } cie_pixel_t;
    cie_pixel_t sh_pixel_in;
    generate
        if (SLOTS_WIDTH > GAMMA_WIDTH) begin : SH_UP
            localparam SHIFT = (SLOTS_WIDTH - GAMMA_WIDTH);
            assign sh_pixel_in.red = (pixel_in.red << SHIFT);
            assign sh_pixel_in.green = (pixel_in.green << SHIFT); 
            assign sh_pixel_in.blue = (pixel_in.blue << SHIFT);
        end else begin : SH_DOWN
            localparam SHIFT = (GAMMA_WIDTH - SLOTS_WIDTH);
            assign sh_pixel_in.red = (pixel_in.red >> SHIFT);
            assign sh_pixel_in.green = (pixel_in.green >> SHIFT);
            assign sh_pixel_in.blue = (pixel_in.blue >> SHIFT);
        end
    endgenerate

    assign pixel_out[2] = sh_pixel_in.red;
    assign pixel_out[1] = (sh_pixel_in.green >> 1) + (sh_pixel_in.green >> 7);
    assign pixel_out[0] = sh_pixel_in.blue;

endmodule
