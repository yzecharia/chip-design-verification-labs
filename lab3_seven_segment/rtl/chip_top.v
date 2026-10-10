`timescale 1ns/1ps
module chip_top #(
    parameter MAX_TICK = 50000,
    parameter MAX_COUNT = 2000
 ) (
    input CLK100MHZ, CPU_RESETN,
    input [15:0] SW,
    input BTNC, BTND,
    output DP,
    output [6:0] ss_dig,
    output [7:0] disp_an
);
    wire tick;
    wire pressed_c, pressed_d;

    wire start;
    wire [19:0] bcd_val;

    wire dec_hex;
    wire [15:0] sw_reg;

    reg reset_n_sync = 1'b0, reset_n_sync0 = 1'b0;
    always @(posedge CLK100MHZ) begin
        reset_n_sync0 <= CPU_RESETN;
        reset_n_sync <= reset_n_sync0;
    end

    tick_gen #(.MAX_TICK(MAX_TICK)) tick_gen_i (CLK100MHZ, reset_n_sync, tick);

    // Center buton
    btn_hold_1s #(.MAX_COUNT(MAX_COUNT)) btn_hold_i0 (CLK100MHZ, reset_n_sync, BTNC, tick, pressed_c);
    // Down buton
    btn_hold_1s #(.MAX_COUNT(MAX_COUNT)) btn_hold_i1 (CLK100MHZ, reset_n_sync, BTND, tick, pressed_d);

    value_latch value_latch_i (CLK100MHZ, reset_n_sync, pressed_c, pressed_d, SW, dec_hex, sw_reg);

    assign start = pressed_c | pressed_d;

    binary_2_bcd bin2bcd_i (CLK100MHZ, reset_n_sync, sw_reg, start, bcd_val);

    display_ctrl display_ctrl_i (CLK100MHZ, reset_n_sync, tick, dec_hex, sw_reg, bcd_val, disp_an, ss_dig, DP);
    
endmodule
