`timescale 1ns/1ps
module tb_chip_top ();
    
    localparam MAX_COUNT_BTN_HOLD = 10;
    localparam MAX_COUNT_DEBOUNCE = 4;
    localparam BAUD_RATE = 10000000;
    localparam CYCLES_PER_BIT = 100000000 / BAUD_RATE;
    localparam DISPLAY_RR = 10000000;
    localparam DELAY50 = 20;

    localparam HALF_BIT = CYCLES_PER_BIT / 2;
    localparam SYNC_CYCLES = 2;

    /*
        Timing Calculation for button press:
        1. debounce.v:
            from moment of pressing until btn_d: SYNC_CYCLES(2) + EDGE_CYCLE(1) + (MAX_COUNT_DEBOUNCE-1) + REG_CYCLE(1) = 2+1+3+1 = 7

        2. btn_hld.v:
            from moment of btn unitl held: STATE_CYCLE(1) + (MAX_COUNT_BTN_HOLD-1) = 1 + 9 = 10
        
        3. latch.v
            from moment of held until transmit: LATCH_CYCLE = 1
        total latencey is 1 + 10 + 7 = 18 clk cycles.
        In order to asure a press Need minimum of 11 cycles pressed for btn hold:
            L = 18 - (debounce cycle = 7) - (latch-cycles = 1) + (one cycle for held = 1) = 18 - 7 -1 + 1 = 11;
            MIN_HOLD = STATE_CYCLE + (MAX_COUNT_BTN_HOLD-1) + 1(for held itself) = 11 
        
        The min hold time to get a start count in btn hold but not transmit is: EDGE_CYCLE + (MAX_CDEBOUNCE-1) + 1 = 5
        so SHORT_HOLD = EDGE_CYCLE + (MAX_COUNT_DEBOUNCE-1) + 1 = 5;
        and LONG_HOLD = STATE_CYCLE + (MAX_COUNT_BTN_HOLD-1) + 1 = 11;
    */

    localparam SHORT_HOLD = MAX_COUNT_DEBOUNCE + 1;
    localparam LONG_HOLD = MAX_COUNT_BTN_HOLD + 1;

    localparam FRAME_CYCLES = 10 * CYCLES_PER_BIT;
    localparam TX_LATENCY = (SYNC_CYCLES + 1 + (MAX_COUNT_DEBOUNCE-1) + 1) + (1 + (MAX_COUNT_BTN_HOLD-1)) + 1 + 2;
    localparam NO_TX_WAIT = TX_LATENCY + 2 * FRAME_CYCLES;

    reg clk = 1'b0;
    always #5 clk = !clk;

    reg cpu_reset, btnc;
    reg [11:0] sw;

    wire tx, led0, dp;
    wire [7:0] an;
    wire [6:0] seg;

    integer pass = 0, fail = 0;

    chip_top #(.BAUD_RATE(BAUD_RATE), .DISPLAY_RR(DISPLAY_RR), .MAX_COUNT_DEBOUNCE(MAX_COUNT_DEBOUNCE), .MAX_COUNT_BTN_HOLD(MAX_COUNT_BTN_HOLD), .DELAY50(DELAY50)) dut (
        .clk(clk),
        .cpu_reset(cpu_reset),
        .btnc(btnc),
        .sw(sw),
        .tx(tx),
        .led0(led0),
        .an(an),
        .seg(seg),
        .dp(dp)
    );

    /*
        so the dut gets size if 0 -> 1, 1->32, 2->128, 3-256
        the max size of exp_mem (includes all the transmitions):
        1. each row has size*data + (size-1)*space + 2(for new line) => 2*size + 1;
        2. their are size cols
        so in total size * (2*size + 1) elments in transmition
    */

    localparam MAX_SIZE = 256;
    integer wr_ptr = 0, rd_ptr = 0;
    reg [7:0] exp_mem [0 : MAX_SIZE * (2*MAX_SIZE + 1) - 1];

    task power_on();
        begin
            cpu_reset = 1'b1; btnc = 1'b0; sw = 12'b0;
            while (dut.reset_n !== 1'b1) @(posedge clk);
        end
    endtask

    task reset();
        begin
            @(negedge clk) cpu_reset = 1'b0;
            while (dut.reset_n !== 1'b0) @(posedge clk);
            @(negedge clk); cpu_reset = 1'b1;
            while (dut.reset_n !== 1'b1) @(posedge clk);
        end
    endtask

    task btn_press(input integer cycles_to_press);
        begin
            @(negedge clk); btnc = 1'b1;
            repeat(cycles_to_press) @(posedge clk);
            @(negedge clk) btnc = 1'b0;
        end
    endtask

    reg reset_in_frame = 1'b0;
    always @(negedge dut.reset_n) reset_in_frame = 1'b1;

    reg [9:0] tx_frame;
    reg res_frame;
    always @(negedge tx) begin
        if (dut.reset_n) begin
            reset_in_frame = 1'b0;
            build_byte(); // Got the frame
            if (reset_in_frame) begin
                $display("Time: %7d | Frame cut by reset | dropped", $time);
            end else begin
                // need to check if frame is correct copared to exp_mem
                if (rd_ptr >= wr_ptr) begin
                    fail = fail + 1;
                    $display("Time: %7d | ERROR Unexpected frame | wr_ptr=%0d | rd_ptr=%0d | FAIL", $time, wr_ptr, rd_ptr);
                end else begin
                    res_frame = (tx_frame === {1'b1, exp_mem[rd_ptr], 1'b0});
                    $display("Time: %7d | Check frame (%0d) | actual=%b | expected=%b | %s", $time, rd_ptr, tx_frame, {1'b1, exp_mem[rd_ptr], 1'b0}, res_frame ? "PASS" : "FAIL");
                    if (res_frame) pass = pass + 1;
                    else fail = fail + 1;
                    // incerement to next frame
                    rd_ptr = rd_ptr + 1;
                end
            end
        end
    end

    task build_byte();
        integer i;
        begin
            repeat(HALF_BIT) @(posedge clk);
            tx_frame = {tx, tx_frame[9:1]};
            for (i = 0; i < 9; i = i + 1) begin
                repeat(CYCLES_PER_BIT) @(posedge clk);
                tx_frame = {tx, tx_frame[9:1]};
            end
        end
    endtask

    
    task build_exp(input integer s, input [7:0] d);
        integer row, col;    
        begin
            wr_ptr = 0; rd_ptr = 0;
            for (row = 0; row < s; row = row + 1) begin
                for (col = 0; col < s; col = col + 1) begin
                    exp_mem[wr_ptr] = d; wr_ptr = wr_ptr + 1;
                    if (col == s - 1) begin // if last char in a row print new line
                        exp_mem[wr_ptr] = 8'h0D; wr_ptr = wr_ptr + 1;
                        exp_mem[wr_ptr] = 8'h0A; wr_ptr = wr_ptr + 1;
                    end else begin
                        exp_mem[wr_ptr] = 8'h20; wr_ptr = wr_ptr + 1; // else add a space after the char
                    end
                end 
            end
        end
    endtask

    function integer get_size(input [1:0] s);
        case(s)
            2'd0: get_size = 1;
            2'd1: get_size = 32;
            2'd2: get_size = 128;
            2'd3: get_size = 256;
        endcase
    endfunction

    function integer get_delay(input [1:0] d);
        case(d)
            2'd0: get_delay = 0;
            2'd1: get_delay = DELAY50;
            2'd2: get_delay = 2 * DELAY50;
            2'd3: get_delay = 4 * DELAY50;
        endcase
    endfunction

    task drive(input [7:0] d, input [1:0] s, input [1:0] delay, input integer press);
        begin
            @(negedge clk); sw = {s, delay, d};
            btn_press(press);
        end
    endtask

    task wait_done();
        integer transmition_cycles;
        integer cycles;
        integer delay_cycles;
        begin
            delay_cycles = get_delay(sw[9:8]);
            cycles = 0;
            transmition_cycles = wr_ptr * (2 * 10 * CYCLES_PER_BIT + delay_cycles);
            while (!(rd_ptr == wr_ptr & (dut.ready)) & (cycles < transmition_cycles + 1000)) begin
                @(posedge clk); cycles = cycles + 1;
            end

            if (rd_ptr == wr_ptr & dut.ready) begin
                $display("Time: %7d | Transmition ended correctly | PASS", $time);
                pass = pass + 1;
            end else begin
                $display("Time: %7d | Timeout on transmition | FAIL", $time);
                fail = fail + 1;
            end
        end
    endtask

    task test_transmit(input [7:0] d, input [1:0] s, input [1:0] delay);
        begin
            build_exp(get_size(s), d);
            drive(d, s, delay, LONG_HOLD);
            wait_done();
        end
    endtask

    task test_no_transmit(input [7:0] d, input [1:0] s, input [1:0] delay);
        integer fail_before;
        reg res;
        begin
            fail_before = fail;
            drive(d, s, delay, SHORT_HOLD);
            repeat(NO_TX_WAIT) @(posedge clk);
            res = (fail == fail_before) & dut.ready;
            $display("Time: %7d | No transmition on short press | %s", $time, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    task test_press_mid_transmit();
        integer fail_before;
        reg res;
        begin
            build_exp(get_size(2'd1), 8'h46);
            drive(8'h46, 2'd1, 2'd0, LONG_HOLD);
            repeat(1000) @(posedge clk);
            drive(8'h47, 2'd0, 2'd0, LONG_HOLD);
            wait_done();

            fail_before = fail;
            repeat(NO_TX_WAIT) @(posedge clk);
            res = (fail == fail_before) & dut.ready;
            $display("Time: %7d | Press mid transmition ignored | %s", $time, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    task test_reset_mid_transmit();
        integer fail_before;
        reg res;
        begin
            build_exp(get_size(2'd1), 8'h45);
            drive(8'h45, 2'd1, 2'd0, LONG_HOLD);
            repeat(1000) @(posedge clk);
            reset();
            wr_ptr = rd_ptr;
            res = (tx === 1'b1) & (led0 === 1'b0) & (dut.ready === 1'b1) & (dut.row_out === 0);
            $display("Time: %7d | Reset mid transmition | %s", $time, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;

            fail_before = fail;
            repeat(NO_TX_WAIT) @(posedge clk);
            res = (fail == fail_before) & (tx === 1'b1);
            $display("Time: %7d | No transmition after reset | %s", $time, res ? "PASS" : "FAIL");
            if (res) pass = pass + 1;
            else fail = fail + 1;
        end
    endtask

    initial begin
        power_on();

        test_transmit(8'h41, 2'd0, 2'd0);
        test_no_transmit(8'h42, 2'd0, 2'd0);
        test_transmit(8'h23, 2'd1, 2'd1);
        test_press_mid_transmit();
        test_reset_mid_transmit();

        $display("Time: %7d | TEST %s | pass=%0d | fail=%0d", $time, (fail == 0) ? "PASS" : "FAIL", pass, fail);
        $finish;
    end
endmodule
