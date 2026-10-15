`timescale 1ns/1ps
module tb_uart_phy();

    localparam TEST_BAUD = 10000000;
    localparam COUNT = 100000000 / TEST_BAUD;
    localparam CYCLES_DURING_TRANS = 9*COUNT + COUNT;
    localparam HALF_COUNT = COUNT / 2;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n;
    reg [7:0] data;
    reg start;

    wire tx, done;

    reg [7:0] exp_data;
    wire [9:0] exp_frame = {1'b1, exp_data, 1'b0};
    reg [9:0] recived_frame;
    integer pass = 0, fail = 0;

    uart_phy #(.BAUD_RATE(TEST_BAUD)) uart_phy_i (clk, reset_n, data, start, tx, done);

    task reset ();
        begin
            reset_n = 1'b0; data = 8'b0; start = 1'b0; exp_data = 8'b0;
            repeat (2) @(negedge clk);

            reset_n = 1'b1;
        end
    endtask

    task send_byte (input [7:0] driven_data);
        integer cycles_during_trans;
        reg res;
        begin
            cycles_during_trans = 0;

            @(negedge clk); data = driven_data; exp_data = driven_data; start = 1'b1;

            @(negedge clk) start = 1'b0;

            while (!done & cycles_during_trans < 2*CYCLES_DURING_TRANS)  begin
                @(posedge clk) cycles_during_trans = cycles_during_trans + 1;
            end

            res = (cycles_during_trans == CYCLES_DURING_TRANS);
            $display("Time: %0d | Clock cycles during transmition | actual=%0d | expected=%0d | %s", $time, cycles_during_trans, CYCLES_DURING_TRANS, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    task send_byte_random();
        begin
            send_byte($urandom);
        end
    endtask

    // check we trans in the midle of bit frame
    always @(negedge tx) begin
        uart_rx(recived_frame);
        compare_frames(recived_frame, exp_frame);
    end

    task uart_rx (output [9:0] recived);
        integer i;
        begin
            repeat (HALF_COUNT) @(posedge clk);

            for (i = 0; i < 9; i = i + 1) begin
                recived = {tx, recived[9:1]};
                repeat (COUNT) @(posedge clk);
            end
            recived = {tx, recived[9:1]};
        end
    endtask

    task compare_frames (input [9:0] recived_frame, input [9:0] exp_frame);
        reg res;
        begin
            res = (recived_frame === exp_frame);
            $display("Time: %0d | Frame correctly recived | actual=%0b | expected=%0b | %s", $time, recived_frame, exp_frame, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    initial begin
        $display("Time: %0d | Reset DUT", $time);
        reset();

        $display("Time: %0d | Direct TEST", $time);
        send_byte(8'h00);
        send_byte(8'hAA);
        send_byte(8'h55);
        send_byte(8'hFF);

        $display("Time: %0d | Random TEST", $time);
        repeat (10) send_byte_random();

        $display("Time: %0d | Test transmit after pause", $time);
        send_byte(8'h12);
        repeat(5) @(negedge clk);
        send_byte(8'h34);

        if (fail  == 0 & pass > 0) $display("Time: %0d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %0d | TEST FAIL | %0d/%0d", $time, pass, pass + fail);

        $finish();
    end

endmodule
