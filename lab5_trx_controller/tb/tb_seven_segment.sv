import lab5_pkg::*;

module tb_seven_segment;
    timeunit 1ns;
    timeprecision 1ps;
    seven_segment_data_t ss_in;
    display_ctrl_data_t display_ctrl_data;

    seven_segment ss_i(
        .ss_in(ss_in),
        .display_ctrl_data(display_ctrl_data)
    );

    initial $monitor("Time: %5d | dash=%b | data_val=%b | dp_in=%b | ss_dig=%b | dp=%b",
                 $time, ss_in.dash, ss_in.data_val, ss_in.dp, display_ctrl_data.ss_dig, display_ctrl_data.dp);

    localparam SS_IN_WIDTH = 6;
    integer i;

    initial begin
        ss_in = '0; #(CLK_PERIOD);
        for (i = 0; i<(2**SS_IN_WIDTH)/2 +2; i++) begin
            ss_in = i[SS_IN_WIDTH-1:0]; #(CLK_PERIOD);
        end

        $finish;
    end

endmodule
