import lab7_pkg::*;
import led_rgf_pkg::*;
import cnt_rgf_pkg::*;
import sys_rgf_pkg::*;
`include "lab7_definitions.svh"

module tb_chip_top;
    timeunit 1ns;
    timeprecision 1ps;

    localparam CLKS_PER_BIT = CLK_FREQ / `BAUD_RATE;
    localparam BIT_WAIT = CLKS_PER_BIT * CLK_PERIOD;
    localparam DEB_WAIT = (`DEB_COUNT + 5) * CLK_PERIOD;   // debounce + sync
    localparam MSG_BYTES = 16;                              // write message and read response
    localparam RD_BYTES = 6;                                // read command {RA2A1A0}

    bit clk = '0;
    always #5 clk = !clk;

    logic cpu_reset = '1;
    logic btnu = '0, btnd = '0, btnl = '0, btnr = '0, btnc = '0;
    logic rx = '1;
    logic tx;
    logic [AN_WIDTH-1:0] an;
    logic [SS_DIG_WIDTH-1:0] seg;
    logic dp;
    logic [15:0] led;
    logic led16_r, led16_g, led16_b;
    logic led17_r, led17_g, led17_b;

    chip_top #(
        .BAUD_RATE(`BAUD_RATE),
        .DEB_COUNT(`DEB_COUNT),
        .DISPLAY_RR(`DISPLAY_RR)
    ) dut (
        .clk(clk),
        .cpu_reset(cpu_reset),
        .btnu(btnu), .btnd(btnd), .btnl(btnl), .btnr(btnr), .btnc(btnc),
        .rx(rx),
        .tx(tx),
        .an(an), .seg(seg), .dp(dp),
        .led(led),
        .led16_r(led16_r), .led16_g(led16_g), .led16_b(led16_b),
        .led17_r(led17_r), .led17_g(led17_g), .led17_b(led17_b)
    );

    // RGF index = address bits [23:16]
    localparam [7:0] LED_RGF = LED_RGF_ADDR;
    localparam [7:0] CNT_RGF = CNT_RGF_ADDR;
    localparam [7:0] SYS_RGF = SYS_RGF_ADDR;
    localparam [7:0] BAD_RGF = 8'h05;
    localparam [RGF_ADDR_WIDTH-1:0] CNT_BAD_ADDR = RGF_ADDR_WIDTH'(20);

    int errors = 0;
    logic [RGF_DATA_WIDTH-1:0] rd;

    // expected counter values, every message sent by the testbench updates them
    logic [CNT_WIDTH-1:0] exp_rx = '0, exp_tx = '0, exp_color = '0, exp_config = '0;

    task clear_exp();
        exp_rx = '0;
        exp_tx = '0;
        exp_color = '0;
        exp_config = '0;
    endtask

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        cpu_reset = '0; #(DEB_WAIT);
        cpu_reset = '1; #(DEB_WAIT);
        clear_exp();
    endtask

    // ---------------- UART in ----------------
    task send_byte(input logic [DATA_WIDTH-1:0] b);
        logic [FRAME_WIDTH-1:0] frame;
        frame = {1'b1, b, 1'b0};
        for (int i = 0; i < FRAME_WIDTH; i++) begin
            rx = frame[i]; #(BIT_WAIT);
        end
    endtask

    // the first byte of the message is in the MSB
    task send_packet(input logic [MSG_BYTES-1:0][DATA_WIDTH-1:0] p, input int n);
        for (int i = n - 1; i >= 0; i--) send_byte(p[i]);
    endtask

    task send_string(input string s);
        $display("Time: %0t | TASK: Send %s", $time, s);
        for (int i = 0; i < s.len(); i++) send_byte(s[i]);
        #(CLK_PERIOD * 20);
    endtask

    // ---------------- UART out ----------------
    task recv_byte(output logic [DATA_WIDTH-1:0] b);
        while (tx !== 1'b0) #(CLK_PERIOD);          // start bit
        #(BIT_WAIT / 2);
        for (int i = 0; i < DATA_WIDTH; i++) begin
            #(BIT_WAIT); b[i] = tx;
        end
        #(BIT_WAIT);                                // stop bit
    endtask

    task recv_packet(output logic [MSG_BYTES-1:0][DATA_WIDTH-1:0] p);
        for (int i = MSG_BYTES - 1; i >= 0; i--) recv_byte(p[i]);
    endtask

    // ---------------- register access over UART ----------------
    // {W A2 A1 A0 , V 00 D3 D2 , V 00 D1 D0}
    task write_reg(input logic [7:0] rgf, input logic [RGF_ADDR_WIDTH-1:0] offset, input logic [RGF_DATA_WIDTH-1:0] data);
        $display("Time: %0t | TASK: Write %h to rgf %0d offset %0d", $time, data, rgf, offset);
        send_packet({"{W", rgf, offset[15:8], offset[7:0], ",V", 8'h00, data[31:24], data[23:16], ",V", 8'h00, data[15:8], data[7:0], "}"}, MSG_BYTES);
        #(CLK_PERIOD * 20);
        exp_rx = exp_rx + 1;
        exp_config = exp_config + 1;
    endtask

    // {R A2 A1 A0}, the answer {R A2 A1 A0 , V 00 D3 D2 , V 00 D1 D0} comes on tx while the command ends,
    // so the receiver runs next to the sender (fork)
    task read_reg(input logic [7:0] rgf, input logic [RGF_ADDR_WIDTH-1:0] offset, output logic [RGF_DATA_WIDTH-1:0] data);
        logic [MSG_BYTES-1:0][DATA_WIDTH-1:0] resp;
        fork
            send_packet({80'h0, "{R", rgf, offset[15:8], offset[7:0], "}"}, RD_BYTES);
            recv_packet(resp);
        join
        assert (resp[15:9] === {"{R", rgf, offset[15:8], offset[7:0], ",V"}) else begin
            $error("bad read response header %h", resp);
            errors++;
        end
        data = {resp[7], resp[6], resp[2], resp[1]};
        #(CLK_PERIOD * 20);
        exp_rx = exp_rx + 1;
        exp_config = exp_config + 1;
        exp_tx = exp_tx + 1;
    endtask

    // the counter values in the answer are the values before this read is counted
    task check_reg(input logic [7:0] rgf, input logic [RGF_ADDR_WIDTH-1:0] offset, input logic [RGF_DATA_WIDTH-1:0] exp, input string name);
        logic [RGF_DATA_WIDTH-1:0] data;
        read_reg(rgf, offset, data);
        assert (data === exp) $display("Time: %0t | PASS: %s = %h", $time, name, data);
        else begin
            $error("%s = %h, expected %h", name, data, exp);
            errors++;
        end
    endtask

    // each read is counted before the next one, so the expected value is taken when the read starts
    task check_counters();
        check_reg(CNT_RGF, CNT_RX_PACKET_ADDR, exp_rx, "rx_packet");
        check_reg(CNT_RGF, CNT_TX_PACKET_ADDR, exp_tx, "tx_packet");
        check_reg(CNT_RGF, CNT_COLOR_MSG_ADDR, exp_color, "color_msg");
        check_reg(CNT_RGF, CNT_CONFIG_MSG_ADDR, exp_config, "config_msg");
    endtask

    task send_color(input string s);
        send_string(s);
        exp_rx = exp_rx + 1;
        exp_color = exp_color + 1;
    endtask

    task send_led(input string s);
        send_string(s);
        exp_rx = exp_rx + 1;
        exp_config = exp_config + 1;
    endtask

    // when the chip is disabled all the outputs that the user sees are off
    task check_outputs_off();
        #(CLK_PERIOD * 5);
        assert ((led === '0) && (an === '1) && ({led16_r, led16_g, led16_b, led17_r, led17_g, led17_b} === '0))
            $display("Time: %0t | PASS: outputs are off", $time);
        else begin
            $error("outputs are not off: led = %h, an = %b", led, an);
            errors++;
        end
    endtask

    task check_outputs_on();
        #(CLK_PERIOD * 5);
        assert ((led === dut.leds_out) && (an === dut.disp_cfg.an))
            $display("Time: %0t | PASS: outputs follow the data path", $time);
        else begin
            $error("outputs do not follow the data path: led = %h, an = %b", led, an);
            errors++;
        end
    endtask

    initial begin
        // Scenario 1: after reset the RGFs hold their reset values and answer read commands
        $display("Time: %0t | Scenario 1 - reset values", $time);
        reset_dut();
        check_reg(SYS_RGF, SYS_CTRL_ADDR, 32'h1, "sys_ctrl");
        check_reg(SYS_RGF, SYS_STATUS_ADDR, '0, "sys_status");
        check_reg(LED_RGF, LED_PATTERN_ADDR, '0, "led_pattern");

        // Scenario 2: a value written to a register over UART is read back
        $display("Time: %0t | Scenario 2 - write and read back", $time);
        write_reg(LED_RGF, LED_PATTERN_ADDR, 32'h1);
        check_reg(LED_RGF, LED_PATTERN_ADDR, 32'h1, "led_pattern");

        // Scenario 3: every message type is counted by the right counter
        $display("Time: %0t | Scenario 3 - counters", $time);
        send_color("{R255,G000,B000}");
        send_color("{R010,G020,B030}");
        send_led("{L017}");
        check_counters();

        // Scenario 4: bad offset sets cnt_status, bad RGF index sets sys_status.msb_addr_err (no answer on tx)
        $display("Time: %0t | Scenario 4 - address errors", $time);
        check_reg(CNT_RGF, CNT_BAD_ADDR, '0, "bad offset");
        check_reg(CNT_RGF, CNT_STATUS_ADDR, 32'h1, "cnt_status");
        check_reg(CNT_RGF, CNT_STATUS_ADDR, '0, "cnt_status after read");
        send_packet({80'h0, "{R", BAD_RGF, 8'h00, 8'h00, "}"}, RD_BYTES);
        exp_rx = exp_rx + 1;
        exp_config = exp_config + 1;
        #(BIT_WAIT * FRAME_WIDTH * 2);
        assert (tx === 1'b1) else begin
            $error("tx answered a read from a RGF that does not exist");
            errors++;
        end
        check_reg(SYS_RGF, SYS_STATUS_ADDR, 32'h2, "sys_status");
        check_reg(SYS_RGF, SYS_STATUS_ADDR, '0, "sys_status after read");

        // Scenario 5: en = 0 turns off the leds and the display, the control path keeps working
        $display("Time: %0t | Scenario 5 - enable", $time);
        write_reg(SYS_RGF, SYS_CTRL_ADDR, 32'h0);
        check_outputs_off();
        check_reg(SYS_RGF, SYS_CTRL_ADDR, 32'h0, "sys_ctrl");
        check_outputs_off();
        write_reg(SYS_RGF, SYS_CTRL_ADDR, 32'h1);
        check_outputs_on();

        // Scenario 6: sw reset clears the other RGFs and the counters, en and sys_status are kept
        $display("Time: %0t | Scenario 6 - sw reset", $time);
        write_reg(SYS_RGF, SYS_CTRL_ADDR, 32'h3);
        clear_exp();
        check_reg(CNT_RGF, CNT_RX_PACKET_ADDR, '0, "rx_packet");
        check_reg(LED_RGF, LED_PATTERN_ADDR, '0, "led_pattern");
        check_reg(SYS_RGF, SYS_CTRL_ADDR, 32'h1, "sys_ctrl");

        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        #(CLK_PERIOD * 10); $finish;
    end

    // watchdog
    initial begin
        #(5ms);
        $error("TIMEOUT");
        $finish;
    end

endmodule
