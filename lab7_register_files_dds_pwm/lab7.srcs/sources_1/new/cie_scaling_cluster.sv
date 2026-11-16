import lab7_pkg::*;

module cie_scaling_cluster(
    input corrected_pixel_t led16_gemma, led17_gemma,
    output corrected_pixel_t led16_cie, led17_cie
);

    cie_scaling led16_cie_i (
        .pixel_in(led16_gemma),
        .pixel_out(led16_cie)
    );

    cie_scaling led17_cie_i (
        .pixel_in(led17_gemma),
        .pixel_out(led17_cie)
    );

endmodule
