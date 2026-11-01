`include "lab5_definitions.svh"
module baud_gen #(
    parameter BAUD_RATE = `BAUD_RATE
) (
    input logic clk, reset_n, en, 
    output logic baud_tick
);
    import lab5_pkg::CLK_FREQ;
    localparam COUNT = CLK_FREQ / BAUD_RATE;
    localparam COUNT_BITS = $clog2(COUNT);
    localparam [COUNT_BITS-1:0] ONE = 1;

    logic [COUNT_BITS - 1 : 0] cnt;
    assign baud_tick = (cnt == COUNT - ONE);
    always_ff @(posedge clk) begin
        if (!reset_n) cnt <= '0;
        else if (baud_tick | !en) cnt <= '0;
        else cnt <= cnt + ONE;
    end

endmodule
