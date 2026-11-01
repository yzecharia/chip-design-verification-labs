import lab5_pkg::*;

module rx_display (
    input rx_parsed_t rx_data,
    input logic [AN_WIDTH-1:0] an, 
    output seven_segment_data_t rx_display_data
);
    always_comb begin
        rx_display_data = {1'b0, {DIG_IN_WIDTH{1'b0}}, 1'b1};
        if (!an[2] | !an[3]) rx_display_data.dash = '1;
        unique case(1'b0)
            an[0]: rx_display_data.data_val = rx_data.pixel_value[0]; 
            an[1]: rx_display_data.data_val = rx_data.pixel_value[1];
            an[2]: rx_display_data.data_val = '0;
            an[3]: rx_display_data.data_val = '0;
            an[4]: rx_display_data.data_val = rx_data.col_index[0];
            an[5]: rx_display_data.data_val = rx_data.col_index[1];
            an[6]: rx_display_data.data_val = rx_data.row_index[0];
            an[7]: rx_display_data.data_val = rx_data.row_index[1];
            default: rx_display_data.data_val = '0;
        endcase
    end
endmodule
