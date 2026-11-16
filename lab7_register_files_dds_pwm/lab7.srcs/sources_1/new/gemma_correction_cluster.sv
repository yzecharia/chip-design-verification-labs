import lab7_pkg::*;
import led_rgf_pkg::*;

module gemma_correction_cluster (
    input led_value_t led16, led17,
    output corrected_pixel_t led16_gemma, led17_gemma
);  

    gemma_correction led16_gemma_i (
        .pixel_in(led16),
        .pixel_out(led16_gemma)
    );

    gemma_correction led17_gemma_i (
        .pixel_in(led17),
        .pixel_out(led17_gemma)
    );

endmodule
