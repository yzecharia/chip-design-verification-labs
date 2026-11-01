import lab5_pkg::*;

module tx_display (
    input logic [AN_WIDTH-1:0] an,
    input sw_cfg_t tx_data,
    input logic [ROW_SIZE_WIDTH-1:0] row_out,
    output seven_segment_data_t tx_display_data
);
    localparam DP_DIG = 3;
    //size decode:
    logic [DATA_WIDTH:0] size_val;
    always_comb begin
        unique case(tx_data.size)
            SIZE_1: size_val = SIZE_1_VAL;
            SIZE_32: size_val = SIZE_32_VAL;
            SIZE_128: size_val = SIZE_128_VAL;
            SIZE_256: size_val = SIZE_256_VAL;
            default: size_val = SIZE_1_VAL;
        endcase
    end
    
    logic [1:0][DIG_IN_WIDTH-1:0] size_d;
    assign size_d = size_val[DATA_WIDTH] ? '1 : size_val[DATA_WIDTH-1:0];

    logic [1:0][DIG_IN_WIDTH-1:0] delay_d;
    always_comb begin
        unique case(tx_data.delay)
            DELAY_0MS: delay_d = DELAY_0MS_DISP;
            DELAY_50MS: delay_d = DELAY_50MS_DISP;
            DELAY_100MS: delay_d = DELAY_100MS_DISP;
            DELAY_200MS: delay_d = DELAY_200MS_DISP;
            default: delay_d = DELAY_0MS_DISP;
        endcase
    end

    logic [1:0][DIG_IN_WIDTH-1:0] row_d; assign row_d = row_out[ROW_SIZE_WIDTH-1] ? '1 : row_out[DATA_WIDTH-1:0];

    always_comb begin
        tx_display_data.dp = an[DP_DIG];
        tx_display_data.dash = '0;
        unique case(1'b0)
            an[0]: tx_display_data.data_val = tx_data.data[0];
            an[1]: tx_display_data.data_val = tx_data.data[1];
            an[2]: tx_display_data.data_val = delay_d[0];
            an[3]: tx_display_data.data_val = delay_d[1];
            an[4]: tx_display_data.data_val = size_d[0];
            an[5]: tx_display_data.data_val = size_d[1];
            an[6]: tx_display_data.data_val = row_d[0];
            an[7]: tx_display_data.data_val = row_d[1];
            default: tx_display_data.data_val = '0;
        endcase
    end

endmodule
