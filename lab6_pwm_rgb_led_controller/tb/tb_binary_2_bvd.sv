import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_binary_2_bcd;
    timeunit 1ns;
    timeprecision 1ps;
    localparam SLOTS_WIDTH = $clog2(`SLOTS);

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic start = '0;
    logic [SLOTS_WIDTH-1:0] bin_in = '0;
    logic [NUM_DIGITS-1:0][DIG_IN_WIDTH-1:0] bcd_out;
    logic done;

    binary_2_bcd #(.SLOTS(`SLOTS)) dut (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .bin_in(bin_in),
        .bcd_out(bcd_out),
        .done(done)
    );

    task reset_dut ();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD); reset_n = '1;
    endtask

    function logic[NUM_DIGITS-1:0][DIG_IN_WIDTH-1:0] bin2bcd(input logic [SLOTS_WIDTH-1:0] b);
        for (int i = 0 ; i < NUM_DIGITS; i ++) begin
            bin2bcd[i] = (b / 10**i) % 10;  
        end
    endfunction

    bit converting = '0;
    bit [SLOTS_WIDTH+1:0] cnt;
    always_ff @(posedge clk) begin
        if (!reset_n | done) cnt <='0;
        else if (converting & !start) cnt <= cnt + 1;
    end

    task drive_bin_in(input logic [SLOTS_WIDTH-1:0] b);
        $display("Time: %0t | TASK: Drive bin_in with: %b", $time, b);
        bin_in = b; start = '1; converting = '1; #(CLK_PERIOD);
        start = '0;
        do #(CLK_PERIOD); while (!done);
        converting = '0; 
        assert(cnt - 1 === SLOTS_WIDTH);
        $display("Time: %0t | cnt=%d , SLOTS_WIDTH=%d", $time, cnt, SLOTS_WIDTH);
        #(CLK_PERIOD);
        assert(bcd_out === bin2bcd(b));
    endtask



    initial begin
        reset_dut();

        for (int i = 0; i < `SLOTS; i ++) begin
            drive_bin_in(i);
        end

        $finish;
    end

endmodule
