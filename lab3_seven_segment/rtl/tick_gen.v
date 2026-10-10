`timescale 1ns/1ps
module tick_gen #(parameter MAX_TICK = 50000) (
    input clk, reset_n,
    output tick
);
    localparam TICK_BITS = $clog2(MAX_TICK);
    localparam [TICK_BITS-1:0] MAX_CNT = MAX_TICK -1;
    localparam [TICK_BITS-1:0] ONE = 1;

    reg  [TICK_BITS-1:0] counter;
    
    assign tick = counter == MAX_CNT;

    always @(posedge clk) begin
        if (!reset_n | tick) counter <=  {TICK_BITS{1'b0}};
        else counter <= counter + ONE;
    end


endmodule
