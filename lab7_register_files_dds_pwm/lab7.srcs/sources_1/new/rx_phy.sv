import lab7_pkg::*;
`include "lab7_definitions.svh"

module rx_phy #(
    parameter BAUD_RATE = `BAUD_RATE
) (
    input logic clk, reset_n,
    input logic rx,
    output logic [DATA_WIDTH-1:0] data,
    output logic done
);

    localparam int CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam MID_BIT_CYCLE = CYCLES_PER_BIT / 2;
    localparam START_CHECK_CYCLE_6 = MID_BIT_CYCLE - (CYCLES_PER_BIT / 16);
    localparam START_CHECK_CYCLE_8 = MID_BIT_CYCLE + (CYCLES_PER_BIT / 16);
    localparam CYCLES_WIDTH = $clog2(CYCLES_PER_BIT);
    localparam DATA_BIT_WIDTH = $clog2(DATA_WIDTH);

    rx_phy_state_t state, next;

    // 1. sync + fall edge
    logic rx_prev, rx_sync, rx_meta;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) {rx_prev, rx_sync, rx_meta} <= '0;
        else {rx_prev, rx_sync, rx_meta} <= {rx_sync, rx_meta, rx};
    end
    logic rx_fall; assign rx_fall = rx_prev && !rx_sync;

    logic [CYCLES_WIDTH-1:0] cycles_cnt;
    logic end_bit; assign end_bit = (cycles_cnt == CYCLES_PER_BIT-1);
    logic mid_bit; assign mid_bit = (cycles_cnt == MID_BIT_CYCLE-1);
    logic start_check_6; assign start_check_6 = (cycles_cnt == START_CHECK_CYCLE_6-1);
    logic start_check_8; assign start_check_8 = (cycles_cnt == START_CHECK_CYCLE_8-1);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) cycles_cnt <= '0;
        else if (((state == RX_PHY_IDLE) & rx_fall) | end_bit) cycles_cnt <= '0;
        else if (state != RX_PHY_IDLE) cycles_cnt <= cycles_cnt + 1;
    end

    logic start_check_reg;
    logic check_6_start; assign check_6_start = start_check_6 && rx_sync && (state == RX_PHY_START);
    logic check_mid_start; assign check_mid_start = mid_bit && rx_sync && (state == RX_PHY_START);
    logic check_8_start; assign check_8_start = start_check_8 && rx_sync && (state == RX_PHY_START);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) start_check_reg <= '1;
        else if ((state == RX_PHY_IDLE) & rx_fall) start_check_reg <= '1;
        else if (check_6_start | check_mid_start | check_8_start) start_check_reg <= '0;
    end
    logic start_check_comb; assign start_check_comb = (state == RX_PHY_START) && end_bit && start_check_reg;

    logic [DATA_BIT_WIDTH-1:0] bit_cnt;
    logic last_bit; assign last_bit = (bit_cnt == DATA_WIDTH-1) & end_bit;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) bit_cnt <= '0;
        else if (start_check_comb | last_bit) bit_cnt <= '0;
        else if ((state == RX_PHY_DATA) & end_bit) bit_cnt <= bit_cnt + 1;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= RX_PHY_IDLE;
        else state <= next;
    end

    always_comb begin
        next = state;
        unique case(state)
            RX_PHY_IDLE: next = rx_fall ? RX_PHY_START : RX_PHY_IDLE;
            RX_PHY_START: next = (!end_bit) ? RX_PHY_START : (start_check_comb ? RX_PHY_DATA : RX_PHY_IDLE);
            RX_PHY_DATA: next = (last_bit) ? RX_PHY_STOP : RX_PHY_DATA;
            RX_PHY_STOP: next = (mid_bit) ? RX_PHY_IDLE : RX_PHY_STOP;
            default: next = state;
        endcase
    end

    logic sh_en; assign sh_en = (state == RX_PHY_DATA) && mid_bit;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) data <= '0;
        else if (sh_en) data <= {rx_sync, data[DATA_WIDTH-1:1]};
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) done <= '0;
        else done <= (state == RX_PHY_STOP) && mid_bit && rx_sync;
    end


endmodule
