`timescale 1ns/1ps
module btn_hold_1s #(parameter MAX_COUNT = 2000) (
    input clk, reset_n,
    input click, 
    input tick,
    output pressed_1s
);

    // Need a synchronizer for click because is is async coming into a synch system
    reg click_sync, click_sync0;
    always @(posedge clk) begin
        if (!reset_n) {click_sync, click_sync0} <= 2'b00;
        else begin
            click_sync0 <= click;
            click_sync <= click_sync0;
        end
    end

    // Need to gen a 1s tick counter from the 400 tick gen
    // 2kHz * 1/1Hz = 2000 -> Need to count 2000 ticks of tick. need log2(2000+1) = 10.96 -> reg [10:0] (11 bits)
    // we need 2001 because their is no wrap around so we dont count it, and need to compinsate
    localparam MAX_COUNT_BITS = $clog2(MAX_COUNT + 1);
    localparam [MAX_COUNT_BITS-1:0] MAX_CNT_M1 = MAX_COUNT - 1;
    localparam [MAX_COUNT_BITS-1:0] MAX_CNT = MAX_COUNT;
    localparam [MAX_COUNT_BITS-1:0] ONE = 1;

    reg [MAX_COUNT_BITS-1:0] counter_1s;

    always @(posedge clk) begin
        if (!reset_n | !click_sync) counter_1s <= {MAX_COUNT_BITS{1'b0}};
        else if (tick) begin
            if (counter_1s == MAX_CNT) counter_1s <= counter_1s;
            else counter_1s <= counter_1s + ONE;
        end 
    end

    assign pressed_1s = click_sync & tick & (counter_1s == MAX_CNT_M1);

    
endmodule
