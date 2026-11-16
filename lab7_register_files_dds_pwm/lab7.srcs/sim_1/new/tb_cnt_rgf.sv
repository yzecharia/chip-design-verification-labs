import lab7_pkg::*;
import cnt_rgf_pkg::*;

module tb_cnt_rgf;
    timeunit 1ns;
    timeprecision 1ps;

    // clock - 100MHz, period of 10ns
    bit clk = '0;
    always #5 clk = !clk;

    // dut inputs and outputs
    logic reset_n = '0;
    logic cs = '0, wen = '0, ren = '0;
    logic [RGF_ADDR_WIDTH-1:0] addr = '0;
    parsed_msg_t msg = '0;
    logic tx_msg_sent = '0;
    logic [RGF_DATA_WIDTH-1:0] rdata;

    // device under test
    cnt_rgf dut (
        .clk(clk),
        .reset_n(reset_n),
        .cs(cs),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .msg(msg),
        .tx_msg_sent(tx_msg_sent),
        .rdata(rdata)
    );

    // an offset that does not exist in the CNT RGF
    localparam [RGF_ADDR_WIDTH-1:0] BAD_ADDR = RGF_ADDR_WIDTH'(20);

    // number of failed checks, used for the final PASS / FAIL report
    int errors = 0;
    // expected counter values - updated by the send tasks
    logic [CNT_WIDTH-1:0] exp_rx = '0, exp_tx = '0, exp_color = '0, exp_config = '0;

    // returns 1 when the message type is counted as a color message
    function logic is_color(input msg_type_t t);
        return (t == RGB_CMD);
    endfunction

    // reset for one clock, the expected values go back to their reset values too
    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        reset_n = '1;
        exp_rx = '0;
        exp_tx = '0;
        exp_color = '0;
        exp_config = '0;
    endtask

    // one valid message from the parser = msg_valid high for one clock
    task send_msg(input msg_type_t t);
        $display("Time: %0t | TASK: Send message %s", $time, t.name());
        msg.msg_type = t;
        msg.msg_valid = '1; #(CLK_PERIOD);
        msg.msg_valid = '0;
        exp_rx = exp_rx + 1;
        if (is_color(t)) exp_color = exp_color + 1;
        else exp_config = exp_config + 1;
    endtask

    // one transmitted message from tx_mac = tx_msg_sent high for one clock
    task send_tx();
        $display("Time: %0t | TASK: TX message sent", $time);
        tx_msg_sent = '1; #(CLK_PERIOD);
        tx_msg_sent = '0;
        exp_tx = exp_tx + 1;
    endtask

    // rdata is sampled while ren is high, before the clock edge that clears cnt_status
    task read_reg(input logic [RGF_ADDR_WIDTH-1:0] a, output logic [RGF_DATA_WIDTH-1:0] data);
        cs = '1; ren = '1; addr = a; #1;
        data = rdata; #(CLK_PERIOD - 1);
        cs = '0; ren = '0;
    endtask

    // write access for one clock (cnt_rgf has no wdata, all its registers are read only)
    task write_reg(input logic [RGF_ADDR_WIDTH-1:0] a);
        $display("Time: %0t | TASK: Write to offset %0d", $time, a);
        cs = '1; wen = '1; addr = a; #(CLK_PERIOD);
        cs = '0; wen = '0;
    endtask

    // reads a register and compares it with the expected value
    task check_reg(input logic [RGF_ADDR_WIDTH-1:0] a, input logic [RGF_DATA_WIDTH-1:0] exp, input string name);
        logic [RGF_DATA_WIDTH-1:0] data;
        read_reg(a, data);
        assert (data === exp) $display("Time: %0t | PASS: %s = %0d", $time, name, data);
        else begin
            $error("%s = %0d, expected %0d", name, data, exp);
            errors++;
        end
    endtask

    // reads the four counters and compares them with the expected values
    task check_counters();
        check_reg(CNT_RX_PACKET_ADDR, exp_rx, "rx_packet");
        check_reg(CNT_TX_PACKET_ADDR, exp_tx, "tx_packet");
        check_reg(CNT_COLOR_MSG_ADDR, exp_color, "color_msg");
        check_reg(CNT_CONFIG_MSG_ADDR, exp_config, "config_msg");
    endtask

    // properties that must hold in every scenario
    always @(posedge clk) begin
        if (reset_n) begin
            assert (dut.rx_packet_cnt === dut.color_msg_cnt + dut.config_msg_cnt)
            else begin
                $error("rx_packet is not equal to color_msg + config_msg");
                errors++;
            end
            if (!(cs && ren)) begin
                assert (rdata === '0)
                else begin
                    $error("rdata = %h when the RGF is not read", rdata);
                    errors++;
                end
            end
        end
    end

    // test scenarios
    initial begin
        // Scenario 1: after reset all the counters and cnt_status are 0
        $display("Scenario 1 - reset values");
        reset_dut();
        check_counters();
        check_reg(CNT_STATUS_ADDR, '0, "cnt_status");

        // Scenario 2: messages of every type are counted by rx_packet and by the right type counter
        $display("Scenario 2 - messages of every type");
        send_msg(WRITE_CMD);
        send_msg(READ_CMD);
        send_msg(RGB_CMD);
        send_msg(LED_CMD);
        repeat (5) send_msg(RGB_CMD);
        repeat (3) send_msg(WRITE_CMD);
        check_counters();

        // Scenario 3: tx_msg_sent pulses are counted only by tx_packet
        $display("Scenario 3 - tx messages");
        repeat (4) send_tx();
        check_counters();

        // Scenario 4: read or write to a bad offset sets cnt_status, reading cnt_status clears it
        $display("Scenario 4 - bad offset");
        check_reg(BAD_ADDR, '0, "bad offset");
        check_reg(CNT_STATUS_ADDR, 32'd1, "cnt_status");
        check_reg(CNT_STATUS_ADDR, '0, "cnt_status after read");
        write_reg(BAD_ADDR);
        check_reg(CNT_STATUS_ADDR, 32'd1, "cnt_status");

        // Scenario 5: write to a read only counter and access without cs do nothing
        $display("Scenario 5 - write to a counter and access without cs");
        write_reg(CNT_RX_PACKET_ADDR);
        wen = '1; addr = BAD_ADDR; #(CLK_PERIOD);
        wen = '0;
        check_reg(CNT_STATUS_ADDR, '0, "cnt_status");
        check_counters();

        // Scenario 6: reset in the middle clears all the counters and cnt_status
        $display("Scenario 6 - reset in the middle");
        write_reg(BAD_ADDR);
        reset_dut();
        check_counters();
        check_reg(CNT_STATUS_ADDR, '0, "cnt_status");

        // final report
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule