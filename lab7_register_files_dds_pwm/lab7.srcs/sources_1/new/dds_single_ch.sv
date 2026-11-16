import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;

module dds_single_ch (
    input logic clk, reset_n,
    input logic cnt_wrap, // from a pwm to know when to push the next value
    input pwm_ctrl_t pwm_ch_ctrl,
    input logic pattern_change,
    output [GAMMA_WIDTH-1:0] dds_ch_val
); 
    `include "sin_wave_table.sv"


    /*

        The idea behind this is the phase gives us the starting point,
        freq gives how much to increment each time,
        and mag shifts the output of the table

        we keep a phase accumulator (acc) that is 17 bits:
        000000000 | 00000000
         integer    fraction
         (index)

        integer  = 9 bits, the index into the 512 entry table
        fraction = 8 bits, 256 units = one table entry

        on reset:           acc = {phase, 8'b0}
        on every cnt_wrap:  acc = acc + freq
        always:             index = acc[16:8]

        freq is added to the entire acc and only the integer part is used as the index,
        so the fraction is kept between steps and not thrown away.
        when acc overflows the index goes from 511 back to 0, which is the start of the table.

        after n steps:
            index = phase + n * freq / 256      (integer part only, wraps at 512)
            val   = table[index] * mag          (mag = x1, x2, x4, x8)
            out   = min(val, 1023)

        i picked 256 because it gives the closest output freq:
            out freq = freq 
            
    */



logic [16:0] acc;
always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) acc <= '0;
    else if (pattern_change) acc <= {pwm_ch_ctrl.phase, 8'h0};
    else if (cnt_wrap) acc <= acc + pwm_ch_ctrl.freq;
end 

logic [8:0] idx; assign idx = acc[16:8];
logic [9:0] table_val; assign table_val = wave_table[idx];
logic [GAMMA_WIDTH+2:0] mag_val; assign mag_val = (table_val << pwm_ch_ctrl.mag);
assign dds_ch_val = (mag_val > 1023) ? GAMMA_WIDTH'(1023) : mag_val[GAMMA_WIDTH-1:0];



endmodule
