import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_chip_top;
    timeunit 1ns;
    timeprecision 1ps;

    localparam SLOTS = `SLOTS;
    localparam SLOTS_WIDTH = $clog2(SLOTS);
    localparam CLKS_PER_BIT = CLK_FREQ / `BAUD_RATE;
    localparam BIT_WAIT = CLKS_PER_BIT * CLK_PERIOD;
    localparam DEB_WAIT = (`DEB_COUNT + 5) * CLK_PERIOD;          // debounce + sync + edge
    localparam MSG_BYTES = 19;

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
        .DISPLAY_RR(`DISPLAY_RR),
        .SLOTS(SLOTS)
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

    // ---------------- model: sRGB -> table (1023) -> shift to SLOTS -> CIE ----------------
    function int table_val(input logic [DATA_WIDTH-1:0] s);
        real c, l;
        c = s / 255.0;
        if (c <= 0.04045) l = c / 12.92;
        else l = $pow((c + 0.055) / 1.055, 2.4);
        return int'(l * ((2**GAMMA_WIDTH) - 1));
    endfunction

    function int to_slots(input int t);
        if (SLOTS_WIDTH >= GAMMA_WIDTH) return t << (SLOTS_WIDTH - GAMMA_WIDTH);
        else return t >> (GAMMA_WIDTH - SLOTS_WIDTH);
    endfunction

    function int exp_red(input logic [DATA_WIDTH-1:0] s); return to_slots(table_val(s)); endfunction
    function int exp_green(input logic [DATA_WIDTH-1:0] s);
        int v;
        v = to_slots(table_val(s));
        return (v >> 1) + (v >> 7);
    endfunction
    function int exp_blue(input logic [DATA_WIDTH-1:0] s); return to_slots(table_val(s)); endfunction

    // ---------------- reset ----------------
    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        cpu_reset = '0; #(DEB_WAIT);
        cpu_reset = '1; #(DEB_WAIT);
        assert(tx === '1) else $error("tx = %b after reset, expected idle 1", tx);
        assert({led16_r, led16_g, led16_b, led17_r, led17_g, led17_b} === '0) else $error("rgb leds not off after reset");
        assert(led === 16'h0030) else $error("led = %h after reset, expected cursor on T0 (0030)", led);
    endtask

    // ---------------- UART in ----------------
    task send_byte(input logic [DATA_WIDTH-1:0] b);
        logic [FRAME_WIDTH-1:0] frame;
        frame = {1'b1, b, 1'b0};
        for (int i = 0; i < FRAME_WIDTH; i++) begin
            rx = frame[i]; #(BIT_WAIT);
        end
    endtask

    task send_msg(input string s);
        $display("Time: %0t | TASK: Send %s", $time, s);
        for (int i = 0; i < s.len(); i++) send_byte(s[i]);
        #(CLK_PERIOD * 20);                                        // rx_mac -> parser -> selector
    endtask

    // ---------------- UART out: collect one message from tx ----------------
    task recv_byte(output logic [DATA_WIDTH-1:0] b);
        while (tx !== 1'b0) #(CLK_PERIOD);                         // start bit
        #(BIT_WAIT / 2);
        for (int i = 0; i < DATA_WIDTH; i++) begin
            #(BIT_WAIT); b[i] = tx;
        end
        #(BIT_WAIT);                                               // stop bit
    endtask

    task recv_msg(output string s);
        logic [DATA_WIDTH-1:0] b;
        s = "";
        for (int i = 0; i < MSG_BYTES; i++) begin
            recv_byte(b);
            s = {s, string'(b)};
        end
        $display("Time: %0t | TASK: Received %s", $time, s);
    endtask

    task check_tx(input logic [DATA_WIDTH-1:0] r, g, b);
        string got, exp;
        exp = $sformatf("{R%04d,G%04d,B%04d}", exp_red(r), exp_green(g), exp_blue(b));
        recv_msg(got);
        assert(got == exp) else $error("tx message %s, expected %s", got, exp);
    endtask

    // ---------------- PWM duty: ones in SLOTS consecutive cycles, all six rgb pins at once ----------------
    logic [5:0] rgb; assign rgb = {led16_r, led16_g, led16_b, led17_r, led17_g, led17_b};

    task check_rgb(input int exp [5:0]);
        int ones [5:0];
        #(CLK_PERIOD * 2 * SLOTS);                                 // let the pwm latch at a period boundary
        for (int i = 0; i < 6; i++) ones[i] = 0;
        for (int c = 0; c < SLOTS; c++) begin
            for (int i = 0; i < 6; i++) ones[i] += rgb[i];
            #(CLK_PERIOD);
        end
        for (int i = 0; i < 6; i++)
            assert(ones[i] === exp[i]) else $error("rgb[%0d] (%s) duty = %0d/%0d, expected %0d", i,
                i == 5 ? "led16_r" : i == 4 ? "led16_g" : i == 3 ? "led16_b" : i == 2 ? "led17_r" : i == 1 ? "led17_g" : "led17_b",
                ones[i], SLOTS, exp[i]);
    endtask

    task check_led16(input logic [DATA_WIDTH-1:0] r, g, b);
        check_rgb('{5: exp_red(r), 4: exp_green(g), 3: exp_blue(b), 2: 0, 1: 0, 0: 0});
    endtask

    task check_led17(input logic [DATA_WIDTH-1:0] r, g, b);
        check_rgb('{5: 0, 4: 0, 3: 0, 2: exp_red(r), 1: exp_green(g), 0: exp_blue(b)});
    endtask

    // ---------------- buttons (levels through the debounce) ----------------
    typedef enum logic [2:0] { BTN_U, BTN_D, BTN_L, BTN_R, BTN_C } btn_e;

    task press(input btn_e b);
        $display("Time: %0t | TASK: Press %s", $time, b.name());
        case (b)
            BTN_U: btnu = '1;
            BTN_D: btnd = '1;
            BTN_L: btnl = '1;
            BTN_R: btnr = '1;
            default: btnc = '1;
        endcase
        #(DEB_WAIT);
        {btnu, btnd, btnl, btnr, btnc} = '0;
        #(DEB_WAIT);
    endtask

    initial begin
        reset_dut();

        // tx answers ~16 clocks after the last stop bit starts, so the receiver runs next to the sender (fork)

        // 1. white: pixel to LED16, feedback on tx
        fork
            send_msg("{R255,G255,B255}");
            check_tx(255, 255, 255);
        join
        check_led16(255, 255, 255);

        // 2. red only, lowercase opcodes
        fork
            send_msg("{r255,g000,b000}");
            check_tx(255, 0, 0);
        join
        check_led16(255, 0, 0);

        // 3. move to LED17: colour moves, no tx for an L packet
        send_msg("{L017}");
        check_led17(255, 0, 0);
        assert(tx === '1) else $error("tx busy after an L packet");

        // 4. invalid packet: nothing changes
        send_msg("{R256,G000,B000}");
        check_led17(255, 0, 0);
        assert(tx === '1) else $error("tx busy after an invalid packet");

        // 5. buttons: left x2 -> cursor on T2 (red), down, center -> new value applied + tx
        press(BTN_L); press(BTN_L);
        assert(led === 16'h0600) else $error("led = %h, expected cursor on T2 (0600)", led);
        press(BTN_D);
        check_led17(255, 0, 0);                                    // not applied yet
        fork
            press(BTN_C);
            check_tx(254, 0, 0);
        join
        check_led17(254, 0, 0);

        // 6. back to LED16, off
        send_msg("{L016}");
        fork
            send_msg("{R000,G000,B000}");
            check_tx(0, 0, 0);
        join
        check_led16(0, 0, 0);

        #(CLK_PERIOD * 10); $finish;
    end

    // watchdog
    initial begin
        #(50ms);
        $error("TIMEOUT");
        $finish;
    end

endmodule
