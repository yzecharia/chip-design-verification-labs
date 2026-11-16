import lab7_pkg::*;

module tb_debounce_cluster;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic cpu_reset = '0;
    logic cpu_reset_d;
    btn_ctf_t io_in = '0;
    btn_ctf_t io_d;

    debounce_cluster debounce_cluster_i (
        .clk(clk),
        .cpu_reset(cpu_reset),
        .io_in(io_in),
        .io_d(io_d),
        .cpu_reset_d(cpu_reset_d)
    );

    localparam DEB_COUNT = `DEB_COUNT;
    localparam SYNC_WAIT = 2 * CLK_PERIOD;
    localparam COUNT_WAIT = DEB_COUNT * CLK_PERIOD;
    localparam LATCH_WAIT = 1 * CLK_PERIOD;

    localparam TOTAL_WAIT_FOR_CHANGE = SYNC_WAIT + COUNT_WAIT + LATCH_WAIT;
    localparam RESET_WAIT_FOR_CHANGE = DEB_COUNT + 1;

    initial $monitor("Time: %5d | cpu_reset=%b | cpu_reset_d=%b | io_in=%b | io_d=%b", $time, cpu_reset, cpu_reset_d, io_in, io_d);

    logic [BUTTON_NUM-1:0] io_cfg = {{(BUTTON_NUM-1){1'b0}}, {1'b1}};
    integer i;
    initial begin
        cpu_reset = '1; #(TOTAL_WAIT_FOR_CHANGE);

        // show that every button has a debounce
        for (i = 0; i < BUTTON_NUM; i++) begin
            io_in = io_cfg << i; #(TOTAL_WAIT_FOR_CHANGE);
        end

        // show reset debounce
        $display("Time: %5d | RESET Test", $time);
        #(CLK_PERIOD/4);
        cpu_reset = '0; #1;
        assert(cpu_reset_d === '0) else $error("cpu_reset_d = %b right after cpu_reset low, expected 0", cpu_reset_d);
        assert(io_d === '0) else $error("io_d = %b during reset, expected 0", io_d);
        #(TOTAL_WAIT_FOR_CHANGE);
        cpu_reset = '1; #(SYNC_WAIT + LATCH_WAIT);
        assert(cpu_reset_d === '1) else $error("cpu_reset_d = %b after release, expected 1", cpu_reset_d);
        #(TOTAL_WAIT_FOR_CHANGE * 2);

        // io_cfg is now 10000..
        // show debounce efect only working when pressed (changed for more than COUNT_WAIT)
        $display("Time: %5d | DEBOUNCE Test", $time);
        io_in = '0; #(COUNT_WAIT/4);
        io_in = '1; #(COUNT_WAIT/6);
        io_in = '0; #(COUNT_WAIT/2);
        io_in = '1; #(COUNT_WAIT - 1);
        io_in = '0; #(COUNT_WAIT);
        #(SYNC_WAIT + CLK_PERIOD + LATCH_WAIT);
        $finish;
    end

    property reset_sync_release;
        @(posedge clk)
        $rose(cpu_reset_d) |-> ($past(cpu_reset, 1) & $past(cpu_reset, 2));
    endproperty
    assert property(reset_sync_release);

    property reset_async_assert;
        @(posedge clk)
        !cpu_reset |-> !cpu_reset_d;
    endproperty
    assert property(reset_async_assert);

endmodule
