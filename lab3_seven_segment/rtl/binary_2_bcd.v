`timescale 1ns/1ps
module binary_2_bcd (
    input clk, reset_n,
    input [15:0] sw,
    input start,
    output [19:0] bcd
);

    // Double Dabble algorithim.
    // If a part (ones/tens/hundreds..) >= 5 then we need to add 3 to that number
    // No need to check ten_thousands because max digit is 6, so before last shift is was 3 (0011) -> (0110) so no need to check add 3 (3 smaller then 5 will never be more)
    // one big shift regesiter between the added parts 
    // counter to make sure we do 16 shifts and thats the end.
    // can also add edge case where sw == 16'b0 and reduce calculation time. but wont see a difference on screen because calculation time is 160 ns.
    wire [3:0] ones, tens, hundreds, thousands;
    reg [3:0] ones_reg, tens_reg, hundreds_reg, thousands_reg, ten_thousands_reg;
    reg [4:0] counter;

    assign ones = (ones_reg >= 4'd5) ? ones_reg + 4'd3 : ones_reg;
    assign tens = (tens_reg >= 4'd5) ? tens_reg + 4'd3 : tens_reg;
    assign hundreds = (hundreds_reg >= 4'd5) ? hundreds_reg + 4'd3 : hundreds_reg;
    assign thousands = (thousands_reg >= 4'd5) ? thousands_reg + 4'd3 : thousands_reg;

    wire shift_16 = counter == 5'd16;

    always @(posedge clk) begin
        if (!reset_n | start) counter <= 5'b0;
        else begin
            if (shift_16) counter <= counter;
            else counter <= counter + 5'd1;
        end
    end    

    always @(posedge clk) begin
        if (!reset_n | start) begin
            {ten_thousands_reg, thousands_reg, hundreds_reg, tens_reg, ones_reg} <= 20'b0;
        end
        else if (!shift_16) begin
            ones_reg <= {ones[2:0], sw[15-counter]};
            tens_reg <= {tens[2:0], ones[3]};
            hundreds_reg <= {hundreds[2:0], tens[3]};
            thousands_reg <= {thousands[2:0], hundreds[3]};
            ten_thousands_reg <= {ten_thousands_reg[2:0], thousands[3]};
        end
    end

    assign bcd = {ten_thousands_reg, thousands_reg, hundreds_reg, tens_reg, ones_reg};
endmodule
