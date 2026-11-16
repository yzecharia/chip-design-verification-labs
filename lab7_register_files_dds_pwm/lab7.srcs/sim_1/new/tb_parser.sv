import lab7_pkg::*;

module tb_parser;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    packet_cfg_t pkt_data = '0;
    logic pkt_valid = '0;
    parsed_msg_t msg;

    parser dut (
        .clk(clk),
        .reset_n(reset_n),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid),
        .msg(msg)
    );

    int errors = 0;

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert (msg === '0) else begin
            $error("msg = %h after reset", msg);
            errors++;
        end
        reset_n = '1;
    endtask

    // one packet from rx_mac = pkt_valid high for one clock
    task send_pkt(input packet_cfg_t p);
        $display("Time: %0t | TASK: Send %h", $time, p);
        pkt_data = p;
        pkt_valid = '1; #(CLK_PERIOD);
        pkt_valid = '0;
    endtask

    // msg_valid is high for one clock, so msg is checked right after send_pkt
    task check_msg(input msg_type_t t, input logic [ADDR_BYTES*DATA_WIDTH-1:0] addr, input logic [DATA_BYTES*DATA_WIDTH-1:0] data, input string name);
        assert ((msg.msg_valid === '1) && (msg.msg_type === t) && (msg.msg_data.addr === addr) && (msg.msg_data.data === data))
            $display("Time: %0t | PASS: %s", $time, name);
        else begin
            $error("%s: valid = %b, type = %s, addr = %h, data = %h", name, msg.msg_valid, msg.msg_type.name(), msg.msg_data.addr, msg.msg_data.data);
            errors++;
        end
        #(CLK_PERIOD);
    endtask

    task check_no_msg(input string name);
        assert (msg.msg_valid === '0) $display("Time: %0t | PASS: %s", $time, name);
        else begin
            $error("%s: msg_valid = 1 for an invalid packet", name);
            errors++;
        end
        #(CLK_PERIOD);
    endtask

    initial begin
        reset_dut();

        // Scenario 1: a color message gives RGB_CMD with the three values in binary
        $display("Time: %0t | Scenario 1 - color message", $time);
        send_pkt("{R123,G045,B200}");
        check_msg(RGB_CMD, 24'h0, 48'h7B2DC8, "color message");

        // Scenario 2: a write message gives WRITE_CMD with the 24 bit address and 32 bit data
        $display("Time: %0t | Scenario 2 - write message", $time);
        send_pkt({"{W", 8'h01, 8'h00, 8'h04, ",V", 8'h00, 8'h12, 8'h34, ",V", 8'h00, 8'h56, 8'h78, "}"});
        check_msg(WRITE_CMD, 24'h010004, 48'h1234_5678, "write message");

        // Scenario 3: a read command gives READ_CMD with the address
        $display("Time: %0t | Scenario 3 - read command", $time);
        send_pkt({80'h0, "{R", 8'h02, 8'h00, 8'h08, "}"});
        check_msg(READ_CMD, 24'h020008, 48'h0, "read command");

        // Scenario 4: a led message gives LED_CMD, data 0 for LED16 and 1 for LED17
        $display("Time: %0t | Scenario 4 - led message", $time);
        send_pkt({80'h0, "{L017}"});
        check_msg(LED_CMD, 24'h0, 48'h1, "led 17");
        send_pkt({80'h0, "{L016}"});
        check_msg(LED_CMD, 24'h0, 48'h0, "led 16");

        // Scenario 5: invalid packets do not give a message
        $display("Time: %0t | Scenario 5 - invalid packets", $time);
        send_pkt("{R256,G000,B000}");
        check_no_msg("color value above 255");
        send_pkt({"{W", 8'h01, 8'h00, 8'h04, ",V", 8'h01, 8'h12, 8'h34, ",V", 8'h00, 8'h56, 8'h78, "}"});
        check_no_msg("write with a first V byte that is not 0");
        send_pkt({80'h0, "{L018}"});
        check_no_msg("led value that is not 016 or 017");

        // Scenario 6: lower-case opcodes are accepted like upper-case
        $display("Time: %0t | Scenario 6 - lower-case opcodes", $time);
        send_pkt("{r123,g045,b200}");
        check_msg(RGB_CMD, 24'h0, 48'h7B2DC8, "lower-case color message");
        send_pkt({"{w", 8'h01, 8'h00, 8'h04, ",v", 8'h00, 8'h12, 8'h34, ",v", 8'h00, 8'h56, 8'h78, "}"});
        check_msg(WRITE_CMD, 24'h010004, 48'h1234_5678, "lower-case write message");
        send_pkt({80'h0, "{r", 8'h02, 8'h00, 8'h08, "}"});
        check_msg(READ_CMD, 24'h020008, 48'h0, "lower-case read command");
        send_pkt({80'h0, "{l017}"});
        check_msg(LED_CMD, 24'h0, 48'h1, "lower-case led 17");

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule
