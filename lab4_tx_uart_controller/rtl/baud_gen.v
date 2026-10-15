`timescale 1ns/1ps
module baud_gen #(parameter BAUD_RATE = 57600) (
    input clk, reset_n,
    input en,
    output baud_tick
);
    
    localparam CLK_FREQ = 100000000;
    localparam COUNT = CLK_FREQ / BAUD_RATE;
    localparam COUNT_BITS = $clog2(COUNT);
    localparam [COUNT_BITS-1:0] ONE = 1;

    reg [COUNT_BITS-1:0] tick_cnt;

    assign baud_tick = (tick_cnt == COUNT - 1);

    always @(posedge clk) begin
       if (!reset_n | baud_tick | !en) tick_cnt <= {COUNT_BITS{1'b0}};
    else tick_cnt <= tick_cnt + ONE;
    end

endmodule
