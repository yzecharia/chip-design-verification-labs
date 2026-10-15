`timescale 1ns/1ps
module chip_top #(
    parameter BAUD_RATE = 57600,
    parameter DISPLAY_RR = 4000,
    parameter MAX_COUNT_DEBOUNCE = 2000000,
    parameter MAX_COUNT_BTN_HOLD = 100000000,
    parameter DELAY50 = 5000000
    ) (
    input clk, cpu_reset,
    input btnc,
    input [11:0] sw,
    output tx,
    output led0,
    output [7:0] an,
    output [6:0] seg,
    output dp
);
    
    wire [11:0] sw_d;
    wire btnc_d;
    wire reset_n;
    debounce #(.MAX_COUNT(MAX_COUNT_DEBOUNCE)) debounce_i (
        .clk(clk),
        .cpu_reset(cpu_reset),
        .btnc(btnc),
        .sw(sw),
        .sw_d(sw_d),
        .btnc_d(btnc_d),
        .cpu_reset_d(reset_n)
    );

    wire held;
    btn_hold #(.MAX_COUNT(MAX_COUNT_BTN_HOLD)) btn_hold_i (
        .clk(clk),
        .reset_n(reset_n),
        .btn(btnc_d),
        .held(held)
    );

    wire ready;
    wire [7:0] data;
    wire [1:0] delay, size;
    wire transmit;
    latch latch_i (
        .clk(clk),
        .reset_n(reset_n),
        .ready(ready),
        .sw_d(sw_d),
        .held(held),
        .data(data),
        .delay(delay),
        .size(size),
        .transmit(transmit)
    );

    wire done;
    wire [7:0] drive_data;
    wire start;
    wire [8:0] row_out;
    tx_fsm #(.DELAY50(DELAY50)) tx_fsm_i (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .delay(delay),
        .size(size),
        .transmit(transmit),
        .done(done),
        .drive_data(drive_data),
        .start(start),
        .led0(led0),
        .row_out(row_out),
        .ready(ready)
    );

    uart_phy #(.BAUD_RATE(BAUD_RATE)) uart_phy_i (
        .clk(clk),
        .reset_n(reset_n),
        .data(drive_data),
        .start(start),
        .tx(tx),
        .done(done)
    );

    wire tick;
    baud_gen #(.BAUD_RATE(DISPLAY_RR)) baud_gen_display_i (
        .clk(clk),
        .reset_n(reset_n),
        .en(1'b1),
        .baud_tick(tick)
    );

    display_ctrl display_ctrl_i (
        .clk(clk),
        .reset_n(reset_n),
        .tick(tick),
        .data(data),
        .delay(delay),
        .size(size),
        .row(row_out),
        .an(an),
        .seg(seg),
        .dp(dp)
    );

endmodule
