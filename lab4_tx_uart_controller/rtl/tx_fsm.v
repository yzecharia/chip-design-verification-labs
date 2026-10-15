`timescale 1ns/1ps
module tx_fsm #(parameter DELAY50=5000000)(
    input clk, reset_n,
    input [7:0] data,
    input [1:0] delay,
    input [1:0] size,
    input transmit,
    input done,
    output reg [7:0] drive_data,
    output reg start,
    output reg led0,
    output [8:0] row_out,
    output ready
);
     
    // Delay Calculation: 
    // 1. No delay no need to count anything
    // 2. 50ms -> 100M * 50m = 5,000,000
    // 3. 100ms -> 100M * 100m = 10,000,000
    // 4. 200ms -> 100M * 200m = 20,000,000
    localparam DELAY0=0, DELAY100=2*DELAY50, DELAY200=4*DELAY50;
    localparam DELAY_BITS = $clog2(DELAY200+1); // to cover all delay types i took max(DELAYS)
    localparam [DELAY_BITS-1:0] DELAY_ONE = 1;

    localparam SIZE0 = 1, SIZE1 = 32, SIZE2 = 128, SIZE3 = 256;
    localparam SIZE_BITS = $clog2(SIZE3);
    localparam [SIZE_BITS-1:0] SIZE_ONE = 1;

    localparam [7:0] SPACE_DATA = 8'h20, NEW_LINE_0_DATA = 8'h0D, NEW_LINE_1_DATA = 8'h0A;
    
    localparam IDLE = 0, DATA = 1, SPACE = 2, NEW_LINE_0 = 3, NEW_LINE_1 = 4, WAIT = 5;

    // Registers
    reg [2:0] state, next;
    reg [DELAY_BITS-1:0] delay_reg;
    reg [SIZE_BITS-1:0] size_reg;
    reg [DELAY_BITS-1:0] delay_cnt;
    reg [SIZE_BITS-1:0] col;
    reg [SIZE_BITS:0] row;

    //Decoders
    // 1. delay decodet:
    always @(*) begin
        case (delay) 
            2'd0: delay_reg = DELAY0;
            2'd1: delay_reg = DELAY50;
            2'd2: delay_reg = DELAY100;
            2'd3: delay_reg = DELAY200;
        endcase
    end

    // 2. size decoder:
    always @(*) begin
        case(size)
            2'd0: size_reg = SIZE0-1;
            2'd1: size_reg = SIZE1-1;
            2'd2: size_reg = SIZE2-1;
            2'd3: size_reg = SIZE3-1;
        endcase
    end

    // Signals
    wire last_col = (col == size_reg); 
    wire last_row = (row == size_reg); 

    // Counters
    wire delay_done = (delay_cnt == delay_reg - 1) | (delay_reg == DELAY0);
    // signal do reset wait counter:
    // 1. when coming from SPACE: state == SPACE & done
    // 2. when coming from NEW_LINE1: state == NEW_LINE1 & done & !last_row;
    wire rst_delay_count = ((state == SPACE) & done) | ((state == NEW_LINE_1) & done & !last_row);
    always @(posedge clk) begin
        if (!reset_n | rst_delay_count) delay_cnt <= {DELAY_BITS{1'b0}};
        else if (!delay_done) delay_cnt <= delay_cnt + DELAY_ONE;
    end

    wire rst_counters = (state == IDLE) & transmit;
    // col counter needs to +1 from transition from SPACE TO WAIT
    wire col_transtition = (state == SPACE) & done & !last_col;
    // row counter needs to up one from NEW_LINE_1 transition to WAIT
    wire row_transtition = (state == NEW_LINE_1) & done; 
    always @(posedge clk) begin
        if (!reset_n | rst_counters | row_transtition) col <= {SIZE_BITS{1'b0}};
        else if (col_transtition) col <= col + SIZE_ONE;
    end

    always @(posedge clk) begin
        if (!reset_n | rst_counters) row <= {(SIZE_BITS+1){1'b0}};
        else if (row_transtition) row <= row + {1'b0, SIZE_ONE};
    end

    //FSM
    always @(posedge clk) begin
        if (!reset_n) state <= IDLE;
        else state <= next;
    end

    always @(*) begin
        next = state;
        case (state)
            IDLE: next = transmit ? DATA : IDLE;
            DATA: if (done) next = (last_col) ? NEW_LINE_0 : SPACE;
            SPACE: next = (done) ? WAIT : SPACE;
            NEW_LINE_0: next = (done) ? NEW_LINE_1 : NEW_LINE_0;
            NEW_LINE_1: if (done) next = (last_row) ? IDLE : WAIT;
            WAIT: next = (delay_done) ? DATA : WAIT;
            default: next = state;
        endcase
    end

    // Registered outputs
    wire load_data = ((state == IDLE) & transmit) | ((state == WAIT) & delay_done);
    wire load_space= (state == DATA) & !last_col & done;
    wire load_new_line_0 = (state == DATA) & last_col & done;
    wire load_new_line_1 = (state == NEW_LINE_0) & done;
    always @(posedge clk) begin
        if (!reset_n) {start, drive_data, led0} <= {10{1'b0}};
        else begin
            start <= (load_data | load_space | load_new_line_0 | load_new_line_1);
            if (load_data) {drive_data, led0} <= {data, !led0};
            else if (load_space) drive_data <= SPACE_DATA;
            else if (load_new_line_0) drive_data <= NEW_LINE_0_DATA;
            else if (load_new_line_1) drive_data <= NEW_LINE_1_DATA;
        end
    end
    assign row_out = row;
    assign ready = (state == IDLE);
endmodule
