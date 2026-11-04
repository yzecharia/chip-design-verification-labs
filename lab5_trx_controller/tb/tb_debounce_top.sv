import lab5_pkg::*;

module tb_debounce_top;
    timeunit 1ns;
    timeprecision 1ps;

    bit clk = '0;
    always #5 clk = !clk;

    logic cpu_reset = '0;
    logic cpu_reset_d;
    board_in_t io_in = '0;
    board_in_t io_d;

    debounce_top debounce_top_i (
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

    logic [13:0] io_cfg = {{13{1'b0}}, {1'b1}};
    integer i;
    initial begin
        cpu_reset = '1; #(TOTAL_WAIT_FOR_CHANGE);

        // show that every board_t input has a debounce
        for (i = 0; i < 14; i++) begin
            io_in = io_cfg << i; #(TOTAL_WAIT_FOR_CHANGE);
        end

        // show reset debounce
        $display("Time: %5d | RESET Test", $time);
        cpu_reset = '0; #(TOTAL_WAIT_FOR_CHANGE);
        cpu_reset = '1; #(TOTAL_WAIT_FOR_CHANGE * 2);

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

    property reset_cnt_reset;
    @(posedge clk)
    ($past(debounce_top_i.reset_edge)) |-> debounce_top_i.reset_cnt == '0;
    endproperty
    assert property(reset_cnt_reset);

    property reset_cnt_no_wrap;
        @(posedge clk)
        ($past(debounce_top_i.reset_stable) & !$past(debounce_top_i.reset_edge)) |-> debounce_top_i.reset_cnt == DEB_COUNT-1;
    endproperty
    assert property(reset_cnt_no_wrap);

    

endmodule
