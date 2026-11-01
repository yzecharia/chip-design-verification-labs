`include "lab5_definitions.svh"
import lab5_pkg::*;

module tx_mac
# (
    parameter DELAY_50MS_VAL = `DELAY_50MS_VAL
) (
    input logic clk, reset_n,
    input logic en,
    input sw_cfg_t sw_d,
    input logic transmit,
    input logic done,
    output logic [DATA_WIDTH-1:0] drive_data,
    output logic start, led0,
    output logic [ROW_SIZE_WIDTH-1:0] row_out,
    output logic ready
);

    localparam DELAY_0MS_VAL = 1, DELAY_100MS_VAL = 2 * DELAY_50MS_VAL, DELAY_200MS_VAL = 4 * DELAY_50MS_VAL;
    localparam DELAY_WIDTH = $clog2(DELAY_200MS_VAL);

    localparam COL_SIZE_WIDTH = SIZE_WIDTH; 

    localparam [DELAY_WIDTH-1:0] DELAY_ONE = 1;
    localparam [COL_SIZE_WIDTH-1:0] COL_SIZE_ONE = 1;
    localparam [ROW_SIZE_WIDTH-1:0] ROW_SIZE_ONE = 1;

    tx_mac_state_t state, next;

    logic [DELAY_WIDTH-1:0] delay_reg;
    always_comb begin
        unique case (sw_d.delay)
            DELAY_0MS: delay_reg = DELAY_0MS_VAL - 1;
            DELAY_50MS: delay_reg = DELAY_50MS_VAL - 1;
            DELAY_100MS: delay_reg = DELAY_100MS_VAL - 1;
            DELAY_200MS: delay_reg = DELAY_200MS_VAL - 1;
            default: delay_reg = DELAY_0MS_VAL - 1;
        endcase 
    end

    logic [SIZE_WIDTH-1:0] size_reg;
    always_comb begin
        unique case(sw_d.size)
            SIZE_1: size_reg = SIZE_1_VAL - 1;
            SIZE_32: size_reg = SIZE_32_VAL - 1;
            SIZE_128: size_reg = SIZE_128_VAL - 1;
            SIZE_256: size_reg = SIZE_256_VAL - 1;
            default: size_reg = SIZE_1_VAL - 1;
        endcase
    end

    logic [COL_SIZE_WIDTH-1:0] col_cnt;
    logic last_col;
    assign last_col = (col_cnt == size_reg);
    logic col_cnt_reset;
    assign col_cnt_reset = ((state == TX_MAC_NEW_LINE_1) & done) || ((state == TX_MAC_IDLE) & transmit); // New reset condition (found bug in)
    logic col_cnt_en;
    assign col_cnt_en = (state == TX_MAC_SPACE) & done;
    always_ff @(posedge clk) begin
        if (!reset_n) col_cnt <= '0;
        else if (col_cnt_reset) col_cnt <= '0;
        else if (col_cnt_en) col_cnt <= col_cnt + COL_SIZE_ONE;
    end 

    logic [ROW_SIZE_WIDTH-1:0] row_cnt;
    logic last_row;
    assign last_row = (row_cnt == {1'b0, size_reg});
    logic row_cnt_reset;
    assign row_cnt_reset = (state == TX_MAC_IDLE) & transmit;
    logic row_cnt_en;
    assign row_cnt_en = (state == TX_MAC_NEW_LINE_1) & done;
    always_ff @(posedge clk) begin
        if (!reset_n) row_cnt <= '0;
        else if (row_cnt_reset) row_cnt <= '0;
        else if (row_cnt_en) row_cnt <= row_cnt + ROW_SIZE_ONE;
    end


    logic [DELAY_WIDTH-1:0] delay_cnt;
    logic delay_done; assign delay_done = (delay_cnt == delay_reg);
    logic delay_cnt_reset; assign delay_cnt_reset = ((state == TX_MAC_SPACE) & done) | ((state == TX_MAC_NEW_LINE_1) & done & !last_row);
    always_ff @(posedge clk) begin
        if (!reset_n) delay_cnt <= '0;
        else if (delay_cnt_reset) delay_cnt <= '0;
        else if (!delay_done) delay_cnt <= delay_cnt + DELAY_ONE;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) state <= TX_MAC_IDLE;
        else state <= next;
    end

    always_comb begin
        next = TX_MAC_IDLE;
        if (en)
            unique case(state)
                TX_MAC_IDLE: next = transmit ? TX_MAC_DATA : TX_MAC_IDLE;
                TX_MAC_DATA: next = (!done) ? TX_MAC_DATA : (last_col ? TX_MAC_NEW_LINE_0 : TX_MAC_SPACE);
                TX_MAC_SPACE: next = done ? TX_MAC_DELAY : TX_MAC_SPACE;
                TX_MAC_NEW_LINE_0: next = done ? TX_MAC_NEW_LINE_1 : TX_MAC_NEW_LINE_0;
                TX_MAC_NEW_LINE_1: next = (!done) ? TX_MAC_NEW_LINE_1 : (last_row ? TX_MAC_IDLE : TX_MAC_DELAY);
                TX_MAC_DELAY: next = delay_done ? TX_MAC_DATA : TX_MAC_DELAY;
                default: next = state;
            endcase
    end

    logic data_load; assign data_load = ((state == TX_MAC_IDLE) & transmit) | ((state == TX_MAC_DELAY) & delay_done);
    logic space_load; assign space_load = ((state == TX_MAC_DATA) & done & !last_col);
    logic new_line0_load; assign new_line0_load = ((state == TX_MAC_DATA) & done & last_col);
    logic new_line1_load; assign new_line1_load = ((state == TX_MAC_NEW_LINE_0) & done);
    logic any_load; assign any_load = data_load | space_load | new_line0_load | new_line1_load;
    logic [DATA_WIDTH-1:0] next_drive;
    always_comb begin
        unique case(1'b1)
            data_load: next_drive = sw_d.data;
            space_load: next_drive = SPACE_DATA;
            new_line0_load: next_drive = NEW_LINE_0_DATA;
            new_line1_load: next_drive = NEW_LINE_1_DATA;
            default: next_drive = sw_d.data;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!reset_n) {start, drive_data} <= '0;
        else if (any_load) {start, drive_data} <= {1'b1, next_drive};
        else start <= '0;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) led0 <= '0;
        else if (data_load) led0 <= !led0;
    end

    assign ready = (state == TX_MAC_IDLE);
    assign row_out = row_cnt;
endmodule
