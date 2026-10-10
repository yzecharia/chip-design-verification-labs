`timescale 1ns/1ps
module display_ctrl (
    input clk, reset_n,
    input tick, // 2kHz tick
    input dec_hex,
    input [15:0] hex_val,
    input [19:0] bcd_val,
    output [7:0] display_an,
    output [6:0] ss_dig,
    output dp
);
    
    reg [4:0] ring_reg;

    always @(posedge clk) begin
        if (!reset_n) ring_reg <= 5'b11110;
        else if (tick) ring_reg <= {ring_reg[3:0], ring_reg[4]};
    end
    
    assign display_an = {3'b111, !dec_hex | ring_reg[4], ring_reg[3:0]}; // needed to be zero when dec_hex is 1 and ring[4] is 0 -> dec_hex & !ring[4] = 1 -> !(dec_hex & ring[4]) = !dec_hex | ring[4] = 0

    wire [19:0] val_to_show = (dec_hex) ? bcd_val : {4'b0, hex_val};

    reg [3:0] dig_in;
    always @(*) begin
        case (ring_reg)
            5'b11110: dig_in = val_to_show[3:0];
            5'b11101: dig_in = val_to_show[7:4];
            5'b11011: dig_in = val_to_show[11:8];
            5'b10111: dig_in = val_to_show[15:12];
            5'b01111: dig_in = val_to_show[19:16];
            default: dig_in = val_to_show[3:0];
        endcase
    end

    seven_segment ss_i (dig_in, ss_dig);

    assign dp = 1'b1;
    
endmodule
