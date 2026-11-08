import lab6_pkg::*;
`include "lab6_definitions.svh"
module display_ctrl #(
    parameter DISPLAY_RR = `DISPLAY_RR
) (
    input logic clk, reset_n,
    input logic led_17_16,
    input pixel_parsed_t display_pixel,
    output display_cfg_t display_out
);

    // 1. tick gen for 500hz
    logic tick;
    baud_gen #(.BAUD_RATE(DISPLAY_RR)) display_tick_i (
        .clk(clk),
        .reset_n(reset_n),
        .en(1'b1),
        .baud_tick(tick)
    );

    // 2. rotate an 0 and 500hz rate
    logic [AN_WIDTH-1:0] an;
    always_ff @(posedge clk) begin
        if (!reset_n) an <= AN_RESET_VAL;
        else if (tick) an <= {an[AN_WIDTH-2:0], an[AN_WIDTH-1]};
    end

    logic[DIG_IN_WIDTH-1:0] display_data;
    always_comb begin
        unique case (1'b0)
            an[0]: display_data = display_pixel.value_0[0];
            an[1]: display_data = display_pixel.value_0[1];
            an[2]: display_data = display_pixel.value_1[0];
            an[3]: display_data = display_pixel.value_1[1];
            an[4]: display_data = display_pixel.value_2[0];
            an[5]: display_data = display_pixel.value_2[1];
            an[6]: display_data = led_17_16 ? '0 : DIG_IN_WIDTH'(1);
            an[7]: display_data = led_17_16 ? DIG_IN_WIDTH'(1) : '0;
            default: display_data = '0;
        endcase
    end

    seven_segment ss (
        .data_val(display_data),
        .ss_dig(display_out.seg)
    );

    assign display_out.an = an;
    assign display_out.dp = 1'b1;

endmodule
