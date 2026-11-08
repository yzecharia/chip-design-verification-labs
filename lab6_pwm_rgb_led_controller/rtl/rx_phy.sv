import lab6_pkg::*;
`include "lab6_definitions.svh"

module rx_phy #(
    parameter BAUD_RATE = `BAUD_RATE
) (
    input logic clk, reset_n, en,
    input logic rx,
    output logic [DATA_WIDTH-1:0] data,
    output logic done
);

    localparam TICKS_PER_BIT = 16;
    localparam TICK_CNT = CLK_FREQ / (BAUD_RATE * TICKS_PER_BIT);


    rx_phy_state_t state, next;

    // 1. sync + fall edge
    logic rx_prev, rx_sync, rx_meta;
    always_ff @(posedge clk) begin
        if (!reset_n) {rx_prev, rx_sync, rx_meta} <= '0;
        else {rx_prev, rx_sync, rx_meta} <= {rx_sync, rx_meta, rx};
    end
    logic rx_fall; assign rx_fall = rx_prev && !rx_sync;

    // 2. Cunters
    // tick counter
    localparam TICK_CNT_BITS = (TICK_CNT > 1) ? $clog2(TICK_CNT) : 1;
    localparam [TICK_CNT_BITS-1:0] TICK_ONE = 1;
    localparam [TICK_CNT_BITS-1:0] LAST_CNT = TICK_CNT - 1;
    logic [TICK_CNT_BITS-1:0] tick_cnt;
    logic tick; assign tick = tick_cnt == LAST_CNT;

    always_ff @(posedge clk) begin
        if (!reset_n) tick_cnt <= '0;
        else if (((state == RX_PHY_IDLE) & rx_fall) | tick) tick_cnt <= '0;
        else tick_cnt <= tick_cnt + TICK_ONE;
    end

    // tick16 counter
    localparam TICK16_CNT_BITS = $clog2(TICKS_PER_BIT);
    localparam [TICK16_CNT_BITS-1:0] TICK16_ONE = 1;
    logic [TICK16_CNT_BITS-1:0] tick16_cnt;
    always_ff @(posedge clk) begin
        if (!reset_n) tick16_cnt <= '0;
        else if ((state == RX_PHY_IDLE) & rx_fall) tick16_cnt <= '0;
        else if (tick) tick16_cnt <= tick16_cnt + TICK16_ONE;
    end

    //signals from tick16 counter
    localparam SAMPLE_NUM = 3;
    localparam [TICK16_CNT_BITS-1:0] SAMPLE_TICK = TICKS_PER_BIT / 2 - 1;
    localparam [TICK16_CNT_BITS-1:0] START_CHECK_TICK = SAMPLE_TICK + SAMPLE_NUM;
    localparam [TICK16_CNT_BITS-1:0] LAST_TICK = TICKS_PER_BIT - 1;
    logic tick7; assign tick7 = (tick16_cnt == SAMPLE_TICK) & tick;
    logic tick10; assign tick10 = (tick16_cnt == START_CHECK_TICK) & tick;
    logic tick15; assign tick15 = (tick16_cnt == LAST_TICK) & tick;

    logic [SAMPLE_NUM-1:0] start_samples;
    always_ff @(posedge clk) begin
        if (!reset_n) start_samples <= '0;
        else if ((state == RX_PHY_START) & tick) start_samples <= {start_samples[SAMPLE_NUM-2:0], rx_sync};
    end
    logic start_check;
    always_ff @(posedge clk) begin
        if (!reset_n) start_check <= '0;
        else if (state == RX_PHY_IDLE) start_check <= '0;
        else if ((!(|start_samples)) & tick10) start_check <= '1;
    end 

    // bit counter
    localparam DATA_BITS = $clog2(DATA_WIDTH);
    localparam [DATA_BITS-1:0] BIT_ONE = 1;
    localparam [DATA_BITS-1:0] LAST_BIT = DATA_WIDTH-1;
    logic [DATA_BITS-1:0] bit_cnt;
    always_ff @(posedge clk) begin
        if (!reset_n) bit_cnt <= '0;
        else if ((state == RX_PHY_START) & start_check) bit_cnt <= '0;
        else if ((state == RX_PHY_DATA) & tick15) bit_cnt <= bit_cnt + BIT_ONE;
    end
    logic bit7; assign bit7 = bit_cnt == LAST_BIT;

    // 3. fsm
    always_ff @(posedge clk) begin
        if (!reset_n) state <= RX_PHY_IDLE;
        else state <= next;
    end

    always_comb begin
        next = RX_PHY_IDLE;
        if (en) begin
            unique case(state)
                RX_PHY_IDLE: next = (rx_fall) ? RX_PHY_START : RX_PHY_IDLE;
                RX_PHY_START: next = (!tick15) ? RX_PHY_START : (start_check ? RX_PHY_DATA : RX_PHY_IDLE);
                RX_PHY_DATA: next = (bit7 & tick15) ? RX_PHY_STOP : RX_PHY_DATA;
                RX_PHY_STOP: next = (tick7) ? RX_PHY_IDLE : RX_PHY_STOP;
                default: next = state;
            endcase
        end
    end

    // data_reg
    always_ff @(posedge clk) begin
        if (!reset_n) data <= '0;
        else if ((state == RX_PHY_DATA) & tick7) data <= {rx_sync, data[DATA_WIDTH-1:1]};
    end

    // done reg
    always_ff @(posedge clk) begin
        if (!reset_n) done <= '0;
        else if ((state == RX_PHY_STOP) & tick7) done <= '1;
        else done <= '0;
    end




endmodule
