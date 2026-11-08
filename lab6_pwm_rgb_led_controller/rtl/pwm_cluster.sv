import lab6_pkg::*;
`include "lab6_definitions.svh"

module pwm_cluster #(
    parameter int SLOTS = `SLOTS,
    localparam int SLOTS_WIDTH = $clog2(SLOTS)
) (
    input logic clk, reset_n,
    input logic [2:0][SLOTS_WIDTH-1:0] value,   // [2] = R, [1] = G, [0] = B
    input logic pwm_led,                         // 0 -> LED16, 1 -> LED17
    output logic [2:0] led16,                    // {r, g, b}
    output logic [2:0] led17
);

    // one pwm per channel
    logic [2:0] pwm_signal;
    genvar i;
    generate
        for (i = 0; i < 3; i++) begin : pwm_gen
            pwm #(.SLOTS(SLOTS)) pwm_i(
                .clk(clk),
                .reset_n(reset_n),
                .value(value[i]),
                .pwm_signal(pwm_signal[i])
            );
        end
    endgenerate

    always_comb begin
        if (pwm_led) begin
            led16 = '0;
            led17 = pwm_signal;
        end else begin
            led16 = pwm_signal;
            led17 = '0;
        end
    end

endmodule
