import lab6_pkg::*;

// SLOTS is passed down by name from chip_top (1024 default, 512 .. 8192);
module pwm #(
    parameter int SLOTS = 1024,
    localparam int SLOTS_WIDTH = $clog2(SLOTS)
) (
    input logic clk, reset_n,
    input logic [SLOTS_WIDTH-1:0] value,
    output logic pwm_signal 
);

    logic [SLOTS_WIDTH-1:0] cnt;
    logic cnt_wrap; assign cnt_wrap = (cnt == SLOTS - 1);
    always_ff @(posedge clk) begin
        if (!reset_n) cnt <= '0;
        else if (cnt_wrap) cnt <= '0;
        else cnt <= cnt + 1;
    end

    logic [SLOTS_WIDTH-1:0] value_reg;
    always_ff @(posedge clk) begin
        if (!reset_n) value_reg <= '0;
        else if (cnt_wrap) value_reg <= value;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) pwm_signal <= '0;
        else pwm_signal <= (cnt < value_reg);
    end

endmodule
