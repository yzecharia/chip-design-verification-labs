`timescale 1ns/1ps
module tb_tx_fsm ();

    localparam TEST_DELAY = 20;
    localparam TEST_RATE = 10000000;
    localparam FRAME = 10 * (100000000 / TEST_RATE); // cycles of one byte on the line

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg reset_n, transmit;
    reg [7:0] data;
    reg [1:0] delay, size;
    wire done, start, led0, ready, tx;
    wire [7:0] drive_data;
    wire [8:0] row_out;

    integer pass = 0, fail = 0;
    integer cycle_cnt = 0, first_start, last_start;

    tx_fsm #(.DELAY50(TEST_DELAY)) tx_fsm_i (clk, reset_n, data, delay, size, transmit, done, drive_data, start, led0, row_out, ready);
    uart_phy #(.BAUD_RATE(TEST_RATE)) uart_phy_i (clk, reset_n, drive_data, start, tx, done);

    always @(posedge clk) cycle_cnt = cycle_cnt + 1;

    // wait for the next start pulse from tx_fsm and check the byte it sends to the phy
    task expect_byte (input [7:0] exp);
        begin
            @(posedge clk);
            while (!start) @(posedge clk);
            last_start = cycle_cnt;
            if (drive_data !== exp) begin
                $display("Time: %0d | byte | actual=%h | expected=%h | FAIL", $time, drive_data, exp);
                fail = fail + 1;
            end else pass = pass + 1;
        end
    endtask

    task run (input [7:0] d, input [1:0] dly, input [1:0] sz);
        integer n, dly_cycles, row, col, exp_time;
        begin
            n = (sz == 0) ? 1 : (sz == 1) ? 32 : (sz == 2) ? 128 : 256;
            dly_cycles = (dly == 0) ? 0 : (dly == 1) ? TEST_DELAY : (dly == 2) ? 2*TEST_DELAY : 4*TEST_DELAY;

            // 1. drive config + 1 cycle transmit pulse
            @(negedge clk); data = d; delay = dly; size = sz; transmit = 1'b1;
            @(negedge clk); transmit = 1'b0;

            // 2. expected stream: data, then space or (0D, 0A) at the end of the row
            for (row = 0; row < n; row = row + 1) begin
                for (col = 0; col < n; col = col + 1) begin
                    expect_byte(d);
                    if (row == 0 && col == 0) first_start = last_start;
                    if (col == n - 1) begin
                        expect_byte(8'h0D);
                        expect_byte(8'h0A);
                    end else expect_byte(8'h20);
                end
            end

            // 3. wait for the FSM to go back to IDLE
            while (!ready) @(posedge clk);

            // 4. row counter
            if (row_out !== n) begin
                $display("Time: %0d | row_out | actual=%0d | expected=%0d | FAIL", $time, row_out, n);
                fail = fail + 1;
            end else pass = pass + 1;

            // 5. run time (delay check): every byte takes FRAME + 1 cycles,
            //    and before every data byte (except the first) the FSM waits max(delay, 1) more cycles
            exp_time = (n * (2*n + 1) - 1) * (FRAME + 1) + (n * n - 1) * ((dly_cycles > 1) ? dly_cycles : 1);
            if (last_start - first_start !== exp_time) begin
                $display("Time: %0d | run time | actual=%0d | expected=%0d | FAIL", $time, last_start - first_start, exp_time);
                fail = fail + 1;
            end else pass = pass + 1;

            $display("Time: %0d | RUN data=%h delay=%0d size=%0dx%0d done | fails so far=%0d", $time, d, dly, n, n, fail);
        end
    endtask

    initial begin
        reset_n = 1'b0; transmit = 1'b0; data = 0; delay = 0; size = 0;
        repeat (2) @(negedge clk);
        reset_n = 1'b1;

        run(8'h41, 2'd0, 2'd0); // 1x1
        run(8'hFF, 2'd3, 2'd0); // 1x1, max delay
        run(8'h20, 2'd0, 2'd1); // 32x32, data == space
        run(8'h55, 2'd1, 2'd1); // 32x32, 50ms
        run(8'hAA, 2'd2, 2'd1); // 32x32, 100ms
        run(8'h0D, 2'd3, 2'd1); // 32x32, 200ms
        //run(8'h12, 2'd0, 2'd2); // 128x128

        $display("Time: %0d | TEST %s | pass=%0d | fail=%0d", $time, (fail == 0) ? "PASS" : "FAIL", pass, fail);
        $finish;
    end

endmodule
