import lab6_pkg::*;
`include "lab6_definitions.svh"

module binary_2_bcd #(
    parameter int SLOTS = `SLOTS,
    localparam int SLOTS_WIDTH = $clog2(SLOTS)
)(
    input logic clk, reset_n,
    input logic start,
    input logic [SLOTS_WIDTH-1:0] bin_in,
    output logic [NUM_DIGITS-1:0][DIG_IN_WIDTH-1:0] bcd_out,
    output logic done
);

    // Double Dabble algorithim (same as lab 3).
    // If a digit >= 5 then we need to add 3 to that digit before the shift.
    // SLOTS_WIDTH shifts, MSB first. bin_in is copied to a shift register on start so there is no variable index.
    // No +3 check on thousands: max value is 9999 so thousands can only pass 4 on the last shift.


    localparam [DIG_IN_WIDTH-1:0] DABBLE_LIMIT = 4'd5;
    localparam [DIG_IN_WIDTH-1:0] DABBLE_ADD = 4'd3;
    localparam int CNT_WIDTH = $clog2(SLOTS_WIDTH + 1);
    localparam [CNT_WIDTH-1:0] CNT_ONE = 1;
    localparam [CNT_WIDTH-1:0] LAST_SHIFT = SLOTS_WIDTH;

    // busy: high from start until the last shift
    logic busy;
    logic [CNT_WIDTH-1:0] counter;
    logic shift_done; assign shift_done = (counter == LAST_SHIFT);
    logic shifting; assign shifting = busy & !shift_done;

    always_ff @(posedge clk) begin
        if (!reset_n) busy <= '0;
        else if (start) busy <= '1;
        else if (shift_done) busy <= '0;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) counter <= '0;
        else if (start) counter <= '0;
        else if (shifting) counter <= counter + CNT_ONE;
    end

    logic [DIG_IN_WIDTH-1:0] ones_reg, tens_reg, hundreds_reg, thousands_reg;
    logic [DIG_IN_WIDTH-1:0] ones, tens, hundreds;
    assign ones = (ones_reg >= DABBLE_LIMIT) ? ones_reg + DABBLE_ADD : ones_reg;
    assign tens = (tens_reg >= DABBLE_LIMIT) ? tens_reg + DABBLE_ADD : tens_reg;
    assign hundreds = (hundreds_reg >= DABBLE_LIMIT) ? hundreds_reg + DABBLE_ADD : hundreds_reg;

    // dabble + shift: bin_in MSB enters ones, each digit's MSB moves to the next digit
    logic [SLOTS_WIDTH-1:0] bin_shift;
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            bin_shift <= '0;
            {thousands_reg, hundreds_reg, tens_reg, ones_reg} <= '0;
        end
        else if (start) begin
            bin_shift <= bin_in;
            {thousands_reg, hundreds_reg, tens_reg, ones_reg} <= '0;
        end
        else if (shifting) begin
            bin_shift <= {bin_shift[SLOTS_WIDTH-2:0], 1'b0};
            ones_reg <= {ones[DIG_IN_WIDTH-2:0], bin_shift[SLOTS_WIDTH-1]};
            tens_reg <= {tens[DIG_IN_WIDTH-2:0], ones[DIG_IN_WIDTH-1]};
            hundreds_reg <= {hundreds[DIG_IN_WIDTH-2:0], tens[DIG_IN_WIDTH-1]};
            thousands_reg <= {thousands_reg[DIG_IN_WIDTH-2:0], hundreds[DIG_IN_WIDTH-1]};
        end
    end

    // done: one cycle pulse after the last shift
    always_ff @(posedge clk) begin
        if (!reset_n) done <= '0;
        else done <= busy & shift_done;
    end

    assign bcd_out = {thousands_reg, hundreds_reg, tens_reg, ones_reg};

endmodule
