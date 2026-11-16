import lab7_pkg::*;

module tb_rx_mac;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic done = '0;
    logic [DATA_WIDTH-1:0] data_in = '0;
    packet_cfg_t pkt_data;
    logic pkt_valid;

    rx_mac dut (
        .clk(clk),
        .reset_n(reset_n),
        .done(done),
        .data_in(data_in),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid)
    );

    int errors = 0;

    // counts the pkt_valid pulses and keeps the last packet
    int valid_cnt = 0;
    packet_cfg_t last_pkt = '0;
    always @(posedge clk) begin
        if (pkt_valid) begin
            valid_cnt++;
            last_pkt = pkt_data;
        end
    end

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert ((pkt_valid === '0) && (pkt_data === '0)) else begin
            $error("pkt_valid = %b, pkt_data = %h after reset", pkt_valid, pkt_data);
            errors++;
        end
        reset_n = '1;
    endtask

    // one byte from rx_phy = done high for one clock
    task send_byte(input logic [DATA_WIDTH-1:0] b);
        data_in = b;
        done = '1; #(CLK_PERIOD);
        done = '0; #(CLK_PERIOD);
    endtask

    // the first byte of the message is in the MSB
    task send_bytes(input logic [PACKET_SIZE-1:0][DATA_WIDTH-1:0] p, input int n);
        $display("Time: %0t | TASK: Send %0d bytes", $time, n);
        for (int i = n - 1; i >= 0; i--) send_byte(p[i]);
        #(CLK_PERIOD * 2);
    endtask

    task check_pkt(input int exp_cnt, input packet_cfg_t exp, input string name);
        assert ((valid_cnt == exp_cnt) && (last_pkt === exp)) $display("Time: %0t | PASS: %s", $time, name);
        else begin
            $error("%s: %0d packets (expected %0d), pkt = %h, expected %h", name, valid_cnt, exp_cnt, last_pkt, exp);
            errors++;
        end
    endtask

    initial begin
        reset_dut();

        // Scenario 1: a color message is collected into one packet
        $display("Time: %0t | Scenario 1 - color message", $time);
        send_bytes("{R123,G045,B200}", PACKET_SIZE);
        check_pkt(1, "{R123,G045,B200}", "color message");

        // Scenario 2: a write message with binary address and data bytes
        $display("Time: %0t | Scenario 2 - write message", $time);
        send_bytes({"{W", 8'h00, 8'h00, 8'h04, ",V", 8'h00, 8'h12, 8'h34, ",V", 8'h00, 8'h56, 8'h78, "}"}, PACKET_SIZE);
        check_pkt(2, {"{W", 8'h00, 8'h00, 8'h04, ",V", 8'h00, 8'h12, 8'h34, ",V", 8'h00, 8'h56, 8'h78, "}"}, "write message");

        // Scenario 3: a short read command, the upper bytes of the packet are 0
        $display("Time: %0t | Scenario 3 - read command", $time);
        send_bytes({80'h0, "{R", 8'h02, 8'h00, 8'h08, "}"}, 6);
        check_pkt(3, {80'h0, "{R", 8'h02, 8'h00, 8'h08, "}"}, "read command");

        // Scenario 4: a message with a missing comma is dropped, the next message is received
        $display("Time: %0t | Scenario 4 - broken message", $time);
        send_bytes({8'h0, "{R123G045,B200}"}, 15);
        check_pkt(3, {80'h0, "{R", 8'h02, 8'h00, 8'h08, "}"}, "broken message dropped");
        send_bytes("{R010,G020,B030}", PACKET_SIZE);
        check_pkt(4, "{R010,G020,B030}", "message after a broken one");

        // Scenario 5: '{' in the middle of a message restarts it
        $display("Time: %0t | Scenario 5 - restart in the middle", $time);
        send_bytes({88'h0, "{R123"}, 5);
        send_bytes("{R050,G060,B070}", PACKET_SIZE);
        check_pkt(5, "{R050,G060,B070}", "message restarted by {");

        // Scenario 6: a fourth group is rejected, the next message is received
        $display("Time: %0t | Scenario 6 - fourth group", $time);
        send_bytes({8'h0, "{R001,G002,B003"}, 15);
        send_bytes({80'h0, ",X004}"}, 6);
        check_pkt(5, "{R050,G060,B070}", "fourth group rejected");
        send_bytes("{R011,G022,B033}", PACKET_SIZE);
        check_pkt(6, "{R011,G022,B033}", "message after a fourth group");

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule
