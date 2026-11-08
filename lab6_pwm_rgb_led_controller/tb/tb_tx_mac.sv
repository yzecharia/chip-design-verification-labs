import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_tx_mac;
    timeunit 1ns;
    timeprecision 1ps;

    localparam SLOTS = `SLOTS;
    localparam SLOTS_WIDTH = $clog2(SLOTS);
    localparam MSG_BYTES = 19;
    localparam PHY_CYCLES = 20;                       // fake tx_phy: done this many clocks after tx_start

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic start = '0;
    logic done = '0;
    logic [2:0][SLOTS_WIDTH-1:0] pixel_data = '0;
    logic [DATA_WIDTH-1:0] drive_data;
    logic tx_start;

    tx_mac #(.SLOTS(SLOTS)) dut (
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .done(done),
        .pixel_data(pixel_data),
        .drive_data(drive_data),
        .tx_start(tx_start)
    );

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(tx_start === '0) else $error("tx_start = %b after reset", tx_start);
        reset_n = '1;
    endtask

    function string exp_msg(input logic [2:0][SLOTS_WIDTH-1:0] p);
        return $sformatf("{R%04d,G%04d,B%04d}", p[2], p[1], p[0]);
    endfunction

    task pulse_start();
        $display("Time: %0t | TASK: start", $time);
        start = '1; #(CLK_PERIOD);
        start = '0;
    endtask

    // fake tx_phy: wait for tx_start, take the byte, answer with done PHY_CYCLES later
    // inject = an extra start while the byte is on the line (tx_start is a 1-cycle pulse, so it can't come before the wait)
    task phy_byte(output logic [DATA_WIDTH-1:0] b, input bit inject);
        while (tx_start !== 1'b1) #(CLK_PERIOD);
        b = drive_data;
        if (inject) pulse_start();
        #(CLK_PERIOD * PHY_CYCLES);
        done = '1; #(CLK_PERIOD);
        done = '0;
    endtask

    // collect one message; start_at / start_at2 = byte index where an extra start is injected (-1 = none)
    task recv_msg(output string s, input int start_at, input int start_at2);
        logic [DATA_WIDTH-1:0] b;
        s = "";
        for (int i = 0; i < MSG_BYTES; i++) begin
            phy_byte(b, (i == start_at) || (i == start_at2));
            s = {s, string'(b)};
        end
        $display("Time: %0t | TASK: Received %s", $time, s);
    endtask

    task check_msg(input logic [2:0][SLOTS_WIDTH-1:0] p, input int start_at, input int start_at2);
        string got;
        recv_msg(got, start_at, start_at2);
        assert(got == exp_msg(p)) else $error("got %s, expected %s", got, exp_msg(p));
    endtask

    task check_idle(input int cycles);
        for (int i = 0; i < cycles; i++) begin
            assert(tx_start === '0) else $error("tx_start = 1 while idle");
            #(CLK_PERIOD);
        end
    endtask

    initial begin
        reset_dut();

        // 1. one message
        pixel_data = {SLOTS_WIDTH'(SLOTS / 2), SLOTS_WIDTH'(SLOTS - 1), SLOTS_WIDTH'(3)};
        pulse_start();
        check_msg(pixel_data, -1, -1);
        check_idle(50);

        // 2. zero values
        pixel_data = '0;
        pulse_start();
        check_msg(pixel_data, -1, -1);
        check_idle(50);

        // 3. start in the middle of a message: the message finishes, then a second one follows (pending)
        pixel_data = {SLOTS_WIDTH'(1), SLOTS_WIDTH'(2), SLOTS_WIDTH'(3)};
        pulse_start();
        check_msg(pixel_data, 5, -1);
        check_msg(pixel_data, -1, -1);
        check_idle(50);

        // 4. two starts in the middle of one message: only ONE extra message (pending is a flag, not a counter)
        pulse_start();
        check_msg(pixel_data, 3, 9);
        check_msg(pixel_data, -1, -1);
        check_idle(50);

        #(CLK_PERIOD); $finish;
    end

    // watchdog
    initial begin
        #(5ms);
        $error("TIMEOUT");
        $finish;
    end

endmodule
