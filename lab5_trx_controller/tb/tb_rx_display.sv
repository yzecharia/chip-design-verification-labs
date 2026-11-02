import lab5_pkg::*;

module tb_rx_display;

    rx_parsed_t rx_data;
    logic [AN_WIDTH-1:0] an;
    seven_segment_data_t rx_display_data;

    rx_display dut (
        .rx_data(rx_data),
        .an(an),
        .rx_display_data(rx_display_data)
    );

    function [AN_WIDTH-1:0] gen_an(input int i);
        return ~(1 << i);
    endfunction

    function bit is_dash(input int i);
        return (i == 2) || (i == 3);
    endfunction

    function [DIG_IN_WIDTH-1:0] exp_val(input rx_parsed_t p, input int i);
        unique case(i)
            0: return p.pixel_value[0];
            1: return p.pixel_value[1];
            2, 3: return '0;
            4: return p.col_index[0];
            5: return p.col_index[1];
            6: return p.row_index[0];
            7: return p.row_index[1];
            default: return 'x; 
        endcase
    endfunction

    task drive(input rx_parsed_t p);
        rx_data = p;
        for (int i = 0; i < AN_WIDTH; i++) begin
            an = gen_an(i);
            #(CLK_PERIOD);
            assert(rx_display_data.dash === is_dash(i));
            assert(rx_display_data.dp === '1);
            if (!is_dash(i))
                assert(rx_display_data.data_val === exp_val(p, i));
        end
    endtask

    initial begin
        drive(24'hABCABC);
        drive(24'h123456);
        $finish;
    end



endmodule
