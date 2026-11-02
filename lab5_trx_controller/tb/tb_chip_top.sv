import lab5_pkg::*;
`include "lab5_definitions.svh"

module tb_chip_top;

    bit clk = '0;
    always #5 clk = !clk;

    logic cpu_reset = '0;
    logic [SW_WIDTH-1:0] sw = '0;
    logic btnc = '0;
    logic rx = '1;
    logic tx;
    logic [AN_WIDTH-1:0] an;
    logic [SS_DIG_WIDTH-1:0] seg;
    logic dp;
    logic led0, led15;

    chip_top dut (
        .clk(clk),
        .cpu_reset(cpu_reset),
        .sw(sw),
        .btnc(btnc),
        .rx(rx),
        .tx(tx),
        .an(an),
        .seg(seg),
        .dp(dp),
        .led0(led0),
        .led15(led15)
    );

    localparam DEB_WAIT = (`DEB_COUNT + 5) * CLK_PERIOD;
    localparam HOLD_WAIT = (`DEB_COUNT + `BTN_HOLD_COUNT + 10) * CLK_PERIOD;
    localparam BIT_WAIT = (CLK_FREQ / `BAUD_RATE) * CLK_PERIOD;
    localparam FRAME_WAIT = FRAME_WIDTH * BIT_WAIT;

    task reset_dut();
        $display("Time: %0t | Task: Reset DUT", $time);
        cpu_reset = '0; #(DEB_WAIT);
        cpu_reset = '1; #(DEB_WAIT);
    endtask

    task set_sw(input logic mode, input size_cfg_t size, input delay_cfg_t delay, input logic [DATA_WIDTH-1:0] data);
        $display("Time: %0t | TASK: Set switches: mode=%b, size=%s, delay=%s, data=%h",
                        $time, mode, size.name(), delay.name(), data);
        sw = {mode, size, delay, data};
        #(DEB_WAIT);
    endtask

    task press_btnc();
        $display("Time: %0t | TASK: Press BTNC", $time);
        btnc = '1; #(HOLD_WAIT);
        btnc = '0; #(DEB_WAIT);
    endtask

    task send_byte(input logic [DATA_WIDTH-1:0] data);
        rx = '0; #(BIT_WAIT);
        for (int i = 0; i < DATA_WIDTH; i++) begin
            rx = data[i]; #(BIT_WAIT);
        end
        rx = '1; #(BIT_WAIT);
    endtask

    task send_msg(input logic [PACKET_SIZE*DATA_WIDTH-1:0] msg);
        $display("Time: %0t | TASK: Send message: %s", $time, msg);
        for (int i = PACKET_SIZE-1; i >= 0; i--) begin
            send_byte(msg[i*DATA_WIDTH +: DATA_WIDTH]);
        end
        #(BIT_WAIT);
    endtask

    task wait_frames(input int n);
        $display("Time: %0t | TASK: Wait %0d frames", $time, n);
        #(FRAME_WAIT * n);
    endtask

    initial begin
        reset_dut();

        set_sw('0, SIZE_1, DELAY_0MS, 8'h41);
        press_btnc();
        wait_frames(5);

        set_sw('0, SIZE_32, DELAY_50MS, 8'h5A);
        press_btnc();
        wait_frames(2200);

        set_sw('1, SIZE_1, DELAY_0MS, 8'h00);
        send_msg("{R001,C002,V128}");
        send_msg("{r010,c020,v255}");
        send_msg("{R300,C005,V009}");
        press_btnc();

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
