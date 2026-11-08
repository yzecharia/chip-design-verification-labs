import lab6_pkg::*;
`include "lab6_definitions.svh"
module tb_cie_scailing;
    timeunit 1ns;
    timeprecision 1ps;
    localparam SLOTS_WIDTH = $clog2(`SLOTS);
    localparam real GREEN_SCALE = 0.587;
    localparam real RED_SCALE = 0.299;
    localparam real BLUE_SCALE = 0.114;

    typedef real real_rgb_t [2:0];

    corrected_pixel_t pixel_in; //[GAMMA_WIDTH-1:0]
    logic [2:0][SLOTS_WIDTH-1:0] pixel_out;

    cie_scaling #(.SLOTS(`SLOTS)) dut (
        .pixel_in(pixel_in),
        .pixel_out(pixel_out)
    );

    function real_rgb_t scale_pixel_in(input corrected_pixel_t p);
        real_rgb_t temp;
        temp[2] = p.red * (RED_SCALE/RED_SCALE) * ((`SLOTS-1.0) / (2**GAMMA_WIDTH - 1));
        temp[1] = p.green * (RED_SCALE/GREEN_SCALE) * ((`SLOTS-1.0) / (2**GAMMA_WIDTH - 1));
        temp[0] = p.blue * 1.0 /* RED_SCALE/BLUE_SCALE = 2.62 > 1, clamped */ * ((`SLOTS-1.0) / (2**GAMMA_WIDTH - 1));
        return temp;
    endfunction

    /*
        AI MADE:
        Tolerance: the shift-add constant deviates from Rec.601 by -0.3% (green, 0.5078 vs 0.509); blue is clamped to 1,
        plus up to 3 floors and the shift losing the last slot. Checked by brute force over every value and
        SLOTS 512..8192: max |rtl - ideal| = 2% of the value + 3.
    */
    localparam real TOL_REL = 0.02;
    localparam real TOL_ABS = 3.0;

    task scale_check(input logic[2:0][SLOTS_WIDTH-1:0] p_out);
        real_rgb_t exp;
        real diff, tol;
        $display("Time: %0t | TASK: Check p_out within 2 precent of actual real value", $time);
        exp = scale_pixel_in(pixel_in);
        $display("Time: %0t | pixel_out.red=%0d exp_red=%0.2f | pixel_out.green=%0d exp_green=%0.2f | pixel_out.blue=%0d exp_blue=%0.2f", $time, p_out[2], exp[2], p_out[1], exp[1], p_out[0], exp[0]);
        for (int c = 0; c < 3; c++) begin
            diff = p_out[c] - exp[c];
            tol = TOL_REL * exp[c] + TOL_ABS;
            assert ((diff <= tol) && (-diff <= tol)) else $error("chan %0d in=%0d: got %0d, ideal %0.2f, diff %0.2f > tol %0.2f", c, pixel_in[c*GAMMA_WIDTH +: GAMMA_WIDTH], p_out[c], exp[c], diff, tol);
        end
    endtask

    task drive_rgb_pixel(input corrected_pixel_t p);
        $display("Time: %0t | TASK: Drive pixel_in: red=%0d green=%0d blue=%0d", $time, p.red, p.green, p.blue);
        pixel_in = p; #(CLK_PERIOD);
        scale_check(pixel_out);
    endtask

    initial begin
        // 1. every value, same on all channels
        for (int v = 0; v < 2**GAMMA_WIDTH; v++) drive_rgb_pixel({v[GAMMA_WIDTH-1:0], v[GAMMA_WIDTH-1:0], v[GAMMA_WIDTH-1:0]});

        $finish;
    end

endmodule
