import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_baud_gen;
    timeunit 1ns;
    timeprecision 1ps;
    localparam BAUD_COUNT = (CLK_FREQ/`BAUD_RATE);
    localparam TICK_WAIT = (BAUD_COUNT - 1) * CLK_PERIOD;
    localparam HALF_WAIT = (BAUD_COUNT / 2) * CLK_PERIOD;

    bit clk = '0;
    always #5 clk =!clk;

    bit reset_n, en, baud_tick;

    baud_gen #(.BAUD_RATE(`BAUD_RATE)) baud_gen_i (
        .clk(clk),
        .reset_n(reset_n),
        .en(en),
        .baud_tick(baud_tick)
    );

    task reset_dut(input bit en_reset);
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; 
        if (en_reset) en = '0;
        #(CLK_PERIOD);
        reset_n = '1;
    endtask

    task en_baud_gen(input int wait_time, input bit lower_en);
        $display("Time: %0t | TASK: Raise enable for %0d ns", $time, wait_time);
        en = '1; #(wait_time);
        if (lower_en) begin    
            $display("Time: %0t | TASK: Lower enable", $time);
            en = '0;
        end
    endtask

    initial $monitor("Time: %0t | en=%0b | baud_tick=%0b", $time, en, baud_tick);

    initial begin
        reset_dut('1);
        assert(!baud_tick);


        en_baud_gen(TICK_WAIT, '1);
        assert(baud_tick); #(CLK_PERIOD);

        en_baud_gen(HALF_WAIT, '1);
        assert(!baud_tick); #(CLK_PERIOD);
        
        $display("Time: %0t | Reset mid en", $time);
        en_baud_gen(HALF_WAIT, '0);
        assert(!baud_tick);
        reset_dut('0);
        assert(!baud_tick);
        en_baud_gen(TICK_WAIT, '1);
        assert(baud_tick);
        #(CLK_PERIOD); $finish;

    end


    int count;
    always_ff @(posedge clk) begin
        if (!reset_n | !en | (count == BAUD_COUNT-1)) count <= '0;
        else if (en) count <= count + 1;
    end

    bit valid_en; assign valid_en = (count == BAUD_COUNT-1);

    property p_tick_after_count;
        @(posedge clk)
        disable iff (!reset_n)
        (valid_en) |-> (baud_tick);
    endproperty
    assert property(p_tick_after_count);

    property p_baud_tick_one_cycle;
        @(posedge clk)
        disable iff(!reset_n)
        ($past(baud_tick)) |-> (!baud_tick); 
    endproperty
    assert property(p_baud_tick_one_cycle);

    property p_reset_press;
        @(posedge clk)
        (!reset_n) |=> (baud_tick == '0);
    endproperty
    assert property(p_reset_press);



endmodule
