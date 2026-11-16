import lab7_pkg::*;

module tb_tx_mac;
    timeunit 1ns;
    timeprecision 1ps;

    localparam PHY_CYCLES = 20; // fake tx_phy: done this many clocks after tx_start

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic done = '0;
    tx_mac_in_t tx_in = '0;
    logic [DATA_WIDTH-1:0] drive_data;
    logic tx_start, tx_msg_sent;

    tx_mac dut (
        .clk(clk),
        .reset_n(reset_n),
        .done(done),
        .tx_in(tx_in),
        .drive_data(drive_data),
        .tx_start(tx_start),
        .tx_msg_sent(tx_msg_sent)
    );

    int errors = 0;

    // counts the tx_msg_sent pulses
    int sent_cnt = 0;
    always @(posedge clk) begin
        if (tx_msg_sent) sent_cnt++;
    end

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert ((tx_start === '0) && (tx_msg_sent === '0)) else begin
            $error("tx_start = %b, tx_msg_sent = %b after reset", tx_start, tx_msg_sent);
            errors++;
        end
        reset_n = '1;
        sent_cnt = 0;
    endtask

    // {R A2 A1 A0 , V 00 D3 D2 , V 00 D1 D0}
    function logic [PACKET_SIZE-1:0][DATA_WIDTH-1:0] exp_msg(input msg_data_t m);
        return {"{R", m.addr[2], m.addr[1], m.addr[0], ",V", 8'h00, m.data[3], m.data[2], ",V", 8'h00, m.data[1], m.data[0], "}"};
    endfunction

    // read data from reg_interconnect = start high for one clock
    task pulse_start(input msg_data_t m);
        $display("Time: %0t | TASK: Start, addr = %h, data = %h", $time, m.addr, m.data);
        tx_in.msg = m;
        tx_in.start = '1; #(CLK_PERIOD);
        tx_in.start = '0;
    endtask

    // fake tx_phy: waits for tx_start, takes the byte and answers with done PHY_CYCLES later
    task phy_byte(output logic [DATA_WIDTH-1:0] b);
        while (tx_start !== 1'b1) #(CLK_PERIOD);
        b = drive_data;
        #(CLK_PERIOD * PHY_CYCLES);
        done = '1; #(CLK_PERIOD);
        done = '0;
    endtask

    task recv_msg(output logic [PACKET_SIZE-1:0][DATA_WIDTH-1:0] p);
        logic [DATA_WIDTH-1:0] b;
        for (int i = PACKET_SIZE - 1; i >= 0; i--) begin
            phy_byte(b);
            p[i] = b;
        end
        #(CLK_PERIOD);
    endtask

    task check_msg(input logic [PACKET_SIZE-1:0][DATA_WIDTH-1:0] got, input msg_data_t m, input int exp_sent, input string name);
        assert ((got === exp_msg(m)) && (sent_cnt == exp_sent)) $display("Time: %0t | PASS: %s", $time, name);
        else begin
            $error("%s: got %h, expected %h, tx_msg_sent pulses = %0d (expected %0d)", name, got, exp_msg(m), sent_cnt, exp_sent);
            errors++;
        end
    endtask

    task check_idle(input int cycles);
        for (int i = 0; i < cycles; i++) begin
            assert (tx_start === '0) else begin
                $error("tx_start = 1 while idle");
                errors++;
            end
            #(CLK_PERIOD);
        end
    endtask

    logic [PACKET_SIZE-1:0][DATA_WIDTH-1:0] got;
    msg_data_t m1, m2, m3;

    initial begin
        m1 = {24'h020008, 48'h5};
        m2 = {24'h010004, 48'h1234_5678};
        m3 = {24'h000000, 48'hFFFF_FFFF};
        reset_dut();

        // Scenario 1: one read response is sent byte by byte and tx_msg_sent pulses once at the end
        $display("Time: %0t | Scenario 1 - one message", $time);
        pulse_start(m1);
        recv_msg(got);
        check_msg(got, m1, 1, "one message");
        check_idle(30);

        // Scenario 2: the four data bytes are sent in the right order
        $display("Time: %0t | Scenario 2 - data byte order", $time);
        pulse_start(m2);
        recv_msg(got);
        check_msg(got, m2, 2, "data byte order");
        check_idle(30);

        // Scenario 3: a start in the middle of a message is ignored, the message is not changed
        $display("Time: %0t | Scenario 3 - start during a message", $time);
        pulse_start(m2);
        fork
            recv_msg(got);
            begin
                #(CLK_PERIOD * PHY_CYCLES * 5);
                pulse_start(m3);
            end
        join
        check_msg(got, m2, 3, "start during a message");
        check_idle(50);

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule
