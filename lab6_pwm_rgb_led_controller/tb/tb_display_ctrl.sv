import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_display_ctrl;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic led_17_16 = '0;
    pixel_parsed_t display_pixel = '0;
    display_cfg_t display_out;

    display_ctrl dut (
        .clk(clk),
        .reset_n(reset_n),
        .led_17_16(led_17_16),
        .display_pixel(display_pixel),
        .display_out(display_out)
    );

    localparam CYCLES_PER_AN = CLK_FREQ / `DISPLAY_RR;
    localparam AN_WAIT = CLK_PERIOD * CYCLES_PER_AN;

    task reset_dut();
        $display("Time: %0t | Task: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(display_out.an === AN_RESET_VAL);
        assert(display_out.seg === SEG_RESET_VAL);
        assert(display_out.dp === 1'b1);
        reset_n = '1;
    endtask

    function [AN_WIDTH-1:0] exp_an(input int i);
        return ~(1 << i);
    endfunction

    task drive(input pixel_parsed_t p, input logic led);
        $display("Time: %0t | TASK: Driving inputs: display_pixel=%h, led_17_16=%b", $time, p, led);
        display_pixel = p;
        led_17_16 = led;
        for (int i = 0; i < AN_WIDTH; i++) begin
            assert(display_out.an === exp_an(i));
            #(AN_WAIT);
        end
    endtask

    initial begin
        reset_dut();

        drive(24'h123456, '0);
        drive(24'hABCDEF, '1);

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
