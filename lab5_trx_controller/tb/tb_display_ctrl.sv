import lab5_pkg::*;
`include "lab5_definitions.svh"

module tb_display_ctrl;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    rx_parsed_t rx_data = '0;
    sw_cfg_t tx_data = '0;
    logic [ROW_SIZE_WIDTH-1:0] row_out = '0;
    logic rx_tx_mode = '0;
    display_cfg_t display_out;

    display_ctrl dut (
        .clk(clk),
        .reset_n(reset_n),
        .rx_data(rx_data),
        .tx_data(tx_data),
        .row_out(row_out),
        .rx_tx_mode(rx_tx_mode),
        .display_out(display_out)
    );

    localparam CYCLES_PER_AN = CLK_FREQ / `DISPLAY_RR;
    localparam AN_WAIT = CLK_PERIOD * CYCLES_PER_AN;

    task reset_dut();
        $display("Time: %0t | Task: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(display_out.an === AN_RESET_VAL);
        assert(display_out.seg === SEG_RESET_VAL);
        assert(display_out.dp === DP_RESET_VAL);
        reset_n = '1;
    endtask

    function [AN_WIDTH-1:0] exp_an(input int i);
        return ~(1 << i);
    endfunction

    task drive(input rx_parsed_t r, input sw_cfg_t t, input logic[ROW_SIZE_WIDTH-1:0] row, input logic mode);
        $display("Time: %0t | TASK: Driving inputs: rx_data=%h, tx_data=%h, row_out=%h, rx_tx_mode=%b",
                        $time, r, t, row, mode);
        rx_data = r;
        tx_data = t;
        row_out = row;
        rx_tx_mode = mode;
        for (int i = 0; i < AN_WIDTH; i++) begin
            assert(display_out.an === exp_an(i));
            #(AN_WAIT);
        end
    endtask

    initial begin
        reset_dut();

        drive(24'h123456, {SIZE_128, DELAY_50MS, 8'hA5}, 9'd77, '0);

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
