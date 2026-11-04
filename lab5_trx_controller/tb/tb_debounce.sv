import lab5_pkg::*;
`include "lab5_definitions.svh"

module tb_debounce;
    timeunit 1ns;
    timeprecision 1ps;
    localparam DEB_WAIT = (`DEB_COUNT + 2 + 1) * 10; // 2 for sync + 1 for state reg
    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic io_in = '0;
    logic io_d;

    debounce #(.DEB_COUNT(`DEB_COUNT)) debounce_i (
        .clk(clk),
        .reset_n(reset_n),
        .io_in(io_in),
        .io_d(io_d)
    );

    initial $monitor("Time: %0t | io_in=%0b | io_d=%0b", $time, io_in, io_d);

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(!io_d);
        reset_n = '1;
    endtask

    bit toggle_value;

    task toggle_io(input bit t_val);
        $display("Time: %0t | TASK: Toggle io to: %0b", $time, t_val);
        io_in = t_val;
        toggle_value = t_val;
    endtask

    task wait_after_toggle(input int wait_time);
        $display("Time: %0t | TASK: Wait for: %0d ns", $time, wait_time);
        #(wait_time);
    endtask


    initial begin
        reset_dut();

        // 1. Regular 
        $display("Time: %0t | Toggle io to 1", $time);
        toggle_io(1); wait_after_toggle(DEB_WAIT); assert(io_d);
        $display("Time: %0t | Toggle io to 0", $time);
        toggle_io(0); wait_after_toggle(DEB_WAIT); assert(!io_d);

        #(CLK_PERIOD);
        
        //2. Debounce Teset
        $display("Time: %0t | Debounce teset", $time);
        toggle_io(1); wait_after_toggle(DEB_WAIT / 3); assert(!io_d);
        toggle_io(0); wait_after_toggle(DEB_WAIT / 6); assert(!io_d);
        toggle_io(1); wait_after_toggle(DEB_WAIT / 10); assert(!io_d);
        toggle_io(0); wait_after_toggle(DEB_WAIT / 5); assert(!io_d);
        toggle_io(1); wait_after_toggle(DEB_WAIT); assert(io_d);
    
        #(CLK_PERIOD);

        //3. Reset mid 
        toggle_io(0); wait_after_toggle(DEB_WAIT / 2); assert(io_d);
        reset_dut(); assert(!io_d);
        toggle_io(1); wait_after_toggle(DEB_WAIT); assert(io_d);

        #(CLK_PERIOD);

        $finish;
    end

    property p_io_d_reset_val;
        @(posedge clk)
        (!reset_n) |=> (!io_d);
    endproperty

    assert property(p_io_d_reset_val);

endmodule
