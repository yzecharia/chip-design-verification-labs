import lab7_pkg::*;
import led_rgf_pkg::*;
`include "lab7_definitions.svh"

module tb_gemma_correction;
    timeunit 1ns;
    timeprecision 1ps;
    led_value_t pixel_in;
    corrected_pixel_t pixel_out;

    localparam real MAX_PIXEL_STRENGTH = 255.0;

    gemma_correction dut (
        .pixel_in(pixel_in),
        .pixel_out(pixel_out)
    );

    task drive_c(input led_value_t c);
        corrected_pixel_t temp;
        pixel_in = c; #(CLK_PERIOD);
        temp = {full_convertion(c.red), full_convertion(c.green), full_convertion(c.blue)};
        $display("Time: %0t | pixel_out.red=%d | calc_pixel.red=%d", $time, pixel_out.red, temp.red);
        assert(pixel_out.red === temp.red);
        assert(pixel_out.green === temp.green);
        assert(pixel_out.blue === temp.blue);
    endtask

    function real cal_c(input [DATA_WIDTH-1:0] val);
        return val / MAX_PIXEL_STRENGTH;
    endfunction

    function real lin_c(input real c);
        if (c <= 0.04045) return c / 12.92;
        else return $pow(((c + 0.055) / 1.055), 2.4);
    endfunction

    function logic [GAMMA_WIDTH-1:0] table_val(input real l);
        return GAMMA_WIDTH'(int'(l * 1023));
    endfunction

    function [GAMMA_WIDTH-1:0] full_convertion(input [DATA_WIDTH-1:0] val);
        return table_val(lin_c(cal_c(val)));
    endfunction

    initial begin
        for (int red = 0; red < 256; red++) begin
            drive_c({DATA_WIDTH'(red), DATA_WIDTH'(0), DATA_WIDTH'(0)});
        end
        for (int green = 0; green < 256; green++) begin
            drive_c({DATA_WIDTH'(0), DATA_WIDTH'(green), DATA_WIDTH'(0)});
        end
        for (int blue = 0; blue < 256; blue++) begin
            drive_c({DATA_WIDTH'(0), DATA_WIDTH'(0), DATA_WIDTH'(blue)});
        end
        $finish;
    end



endmodule
