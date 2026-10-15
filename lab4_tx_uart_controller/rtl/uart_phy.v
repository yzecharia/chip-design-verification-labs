`timescale 1ns/1ps
module uart_phy #(parameter BAUD_RATE = 57600) (
    input clk, reset_n,
    input [7:0] data, 
    input start,
    output tx,
    output done
);
    
    // How it works:
    // 2 States, IDLE and TRANSMIT
    // tx is 1 all the time when not in transmit
    // to move to transmit state we need start (then when in transmit -> pass the state to the baud_gen as en so it starts ticking)
    // done is asserted when transmitted bits counter is 9 and there is a tick
    // Counter counter from 0-9 only in transmit and only when there is a tick to make sure that we space the bits in the correct timing
    // Shift register 10 bits, in IDLE we load it with {10{1'b1}} so line is always 1, and when start we load it with {1'b1, data, 1'b0},
    // then for every count enable is acts as a shift en too, and we shift right while inserting a one
    // {1'b1, sh_reg[9:1]}


    // States + state regs
    localparam IDLE = 0, TRANSMIT = 1;
    reg state, next;


    // tick generator
    wire tick;
    baud_gen #(.BAUD_RATE(BAUD_RATE)) baud_gen_i (clk, reset_n, (state == TRANSMIT), tick);

    // Counter + shift reg
    localparam MAX_COUNT = 10; // count 10 bits
    localparam MAX_COUNT_BITS = $clog2(MAX_COUNT);
    localparam [MAX_COUNT_BITS-1:0] ONE = 1; 
    reg [MAX_COUNT_BITS-1:0] cnt;
    reg [MAX_COUNT-1:0] sh_reg;

    //signal we need:
    // 1. To move from IDLE to Transmit we need start, and it is input signal,
    // 2. To move from TRANSMIT to idle: when count is 9 and their is a tick we just transmitted the last bit (stop bit) so can go back to IDLE
    // 3. shift and count signal, when in state TRANSMIT and tick;
    // 4. signal when to load, when we are in idle and start, and not in transmit
    assign done = (cnt == MAX_COUNT - 1) & tick;
    wire sh_cnt_en = (state == TRANSMIT) & tick;
    wire load = (state == IDLE) & start; 

    // counter control
    // 1. needs to be reset to 0.
    // 2. counts only in transmit ans only when their is a tick else sits idle at 0
    always @(posedge clk) begin
        if (!reset_n | done | state == IDLE) cnt <= {MAX_COUNT_BITS{1'b0}};
        else if (sh_cnt_en) cnt <= cnt + ONE;
    end

    // Shift register control
    // 1. reset to ones
    // 2. at start load with data and start stop bit
    // 3. in sh_cnt_ent shift right and insert 1
    always @(posedge clk) begin
        if (!reset_n | done) sh_reg <= {MAX_COUNT{1'b1}};
        else if (load) sh_reg <= {1'b1, data, 1'b0};
        else if (sh_cnt_en) sh_reg <= {1'b1, sh_reg[9:1]};
    end

    //FSM
    always @(posedge clk) begin
        if (!reset_n) state <= IDLE;
        else state <= next;
    end

    always @(*) begin
        next = state;
        case(state)
            IDLE: next = start ? TRANSMIT : IDLE;
            TRANSMIT: next = done ? IDLE : TRANSMIT;
            default: next = state;
        endcase
    end 

    // output
    assign tx = sh_reg[0];
endmodule
