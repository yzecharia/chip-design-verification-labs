import lab6_pkg::*;

module tb_seven_segment;
    timeunit 1ns;
    timeprecision 1ps;
    logic [DIG_IN_WIDTH-1:0] data_val;
    logic [SS_DIG_WIDTH-1:0] ss_dig;

    seven_segment ss_i(
        .data_val(data_val),
        .ss_dig(ss_dig)
    );

    initial $monitor("Time: %5d | data_val=%h | ss_dig=%b", $time, data_val, ss_dig);

    integer i;

    initial begin
        data_val = '0; #(CLK_PERIOD);
        for (i = 0; i < 2**DIG_IN_WIDTH; i++) begin
            data_val = i[DIG_IN_WIDTH-1:0]; #(CLK_PERIOD);
        end

        $finish;
    end

endmodule
