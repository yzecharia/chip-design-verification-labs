`timescale 1ns/1ps
module latch (
    input clk, reset_n,
    input ready, 
    input [11:0] sw_d,
    input held,
    output reg [7:0] data,
    output reg [1:0] delay,
    output reg [1:0] size,
    output reg transmit
);
    
    wire load_cfg = held & ready;

    // sw reg
    always @(posedge clk) begin
       if (!reset_n) {size, delay, data} <= 12'b0;
       else if (load_cfg) {size, delay, data} <= {sw_d[11:10], sw_d[9:8], sw_d[7:0]}; 
    end


    // transmit reg
    always @(posedge clk) begin
        if (!reset_n) transmit <= 1'b0;
        else transmit <= load_cfg;
    end

endmodule
