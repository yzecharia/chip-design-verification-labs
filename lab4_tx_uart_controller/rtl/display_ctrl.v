`timescale 1ns/1ps
module display_ctrl (
    input clk, reset_n,
    input tick, 
    input [7:0] data,
    input [1:0] delay,
    input [1:0] size,
    input [8:0] row,
    output reg [7:0] an,
    output [6:0] seg,
    output dp
);

    reg [3:0] display_data;

    // Like in lab 3 need a ring shifter for an
    always @(posedge clk) begin
        if (!reset_n) an <= 8'hFE;
        else if (tick) an <= {an[6:0], an[7]};
    end

    // need to call seven_segment
    seven_segment ss_i (display_data, seg);
    
    reg [7:0] delay_decode;
    always @(*) begin
        case(delay)
            2'd0: delay_decode = 8'h00;
            2'd1: delay_decode = 8'h05;
            2'd2: delay_decode = 8'h10;
            2'd3: delay_decode = 8'h20;
        endcase
    end

    reg [7:0] size_decode;
    always @(*) begin
        case(size)
            2'd0: size_decode = 8'h01;
            2'd1: size_decode = 8'h20;
            2'd2: size_decode = 8'h80;
            2'd3: size_decode = 8'hFF;
        endcase
    end

    wire [7:0] row_decode = row[8] ? 8'hFF : row[7:0];

    always @(*) begin
        case(an)
            8'hFE: display_data = data[3:0];
            8'hFD: display_data = data[7:4];
            8'hFB: display_data = delay_decode[3:0];
            8'hF7: display_data = delay_decode[7:4];
            8'hEF: display_data = size_decode[3:0];
            8'hDF: display_data = size_decode[7:4];
            8'hBf: display_data = row_decode[3:0];
            8'h7F: display_data = row_decode[7:4];
            default: display_data = 4'h0;
        endcase
    end 


    assign dp = an[3];

endmodule
