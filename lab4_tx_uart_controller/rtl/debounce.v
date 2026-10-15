`timescale 1ns/1ps
module debounce #(parameter MAX_COUNT = 2000000) (
    input clk,
    input cpu_reset,
    input btnc,
    input [11:0] sw,
    output [11:0] sw_d,
    output btnc_d,
    output cpu_reset_d
);
    
    localparam MAX_COUNT_BITS = $clog2(MAX_COUNT);
    localparam [MAX_COUNT_BITS-1:0] ONE = 1;
    // Debonce, need to wait for 20 ms -> 100M * 20m = 2M = MAX_COUNT
    // Going to use 2 counters, 1 for sw + btnc and 1 from reset (because reset is important buton)
    // 1. Need synchronizer for all the async inputs.
    // 2. Need to detect a change (dual edge detector)
    // 3. once change is detected, start counting, if stable for count == MAX_COUNT - 1 can latch the values to outputs

    // I'll start with reset debounce so that i can use the reset signal as reset for the other debouncer
    // Synchronizer - reset (Initial valuse for reset regs so we start at reset automatically)
    reg reset_sync = 1'b0;
    reg reset_sync_0 = 1'b0;
    always @(posedge clk) begin
        {reset_sync, reset_sync_0} <= {reset_sync_0, cpu_reset};
    end

    // Edge detector - reset
    reg reset_prev = 1'b0;
    always @(posedge clk) begin
        reset_prev <= reset_sync;
    end 
    wire reset_edge = reset_prev ^ reset_sync;

    // Counter - reset
    reg [MAX_COUNT_BITS-1:0] reset_cnt = {MAX_COUNT_BITS{1'b0}};
    wire reset_stable = (reset_cnt == MAX_COUNT - 1);
    always @(posedge clk) begin
        if (reset_edge) reset_cnt <= {MAX_COUNT_BITS{1'b0}};
        else if (!reset_stable) reset_cnt <= reset_cnt + ONE;
    end

    // Output reg - reset
    reg reset_n = 1'b0;
    always @(posedge clk) begin
        if (reset_stable & !reset_edge) reset_n <= reset_sync;
    end

    assign cpu_reset_d = reset_n;

    // Now SW + BTNC (Can use reset now)
    // 1. Synchronizer
    reg [12:0] sw_btn_sync, sw_btn_sync_0;
    always @(posedge clk) begin
        if (!cpu_reset_d) {sw_btn_sync, sw_btn_sync_0} <= {26{1'b0}};
        else {sw_btn_sync, sw_btn_sync_0} <= {sw_btn_sync_0, {sw, btnc}};
    end

    // 2. Edge detector
    reg [12:0] sw_btn_prev;
    always @(posedge clk) begin
        if (!cpu_reset_d) sw_btn_prev <= {13{1'b0}};
        else sw_btn_prev <= sw_btn_sync;
    end
    wire sw_btn_edge = |(sw_btn_prev ^ sw_btn_sync);

    // 3. Counter
    reg [MAX_COUNT_BITS-1:0] sw_btn_cnt;
    wire sw_btn_stable = sw_btn_cnt == MAX_COUNT - 1;
    always @(posedge clk) begin
        if (!cpu_reset_d | sw_btn_edge) sw_btn_cnt <= {MAX_COUNT_BITS{1'b0}};
        else if (!sw_btn_stable) sw_btn_cnt <= sw_btn_cnt + ONE;
    end
    
    // Output reg
    reg [12:0] sw_btn_d;
    always @(posedge clk) begin
        if (!cpu_reset_d) sw_btn_d <= {13{1'b0}};
        else if (sw_btn_stable & !sw_btn_edge) sw_btn_d <= sw_btn_sync;
    end

    assign sw_d = sw_btn_d[12:1];
    assign btnc_d = sw_btn_d[0];

endmodule
