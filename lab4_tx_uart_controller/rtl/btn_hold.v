`timescale 1ns/1ps
// MAX_COUNT = 100M * 1 = 100M

module btn_hold #(parameter MAX_COUNT = 100000000) (
    input clk, reset_n,
    input btn,
    output held
);

    localparam MAX_COUNT_BITS = $clog2(MAX_COUNT);
    localparam [MAX_COUNT_BITS-1:0] ONE = 1;

    localparam IDLE = 0, COUNT = 1, WAIT = 2;
    reg [1:0] state, next;

    reg [MAX_COUNT_BITS-1:0] cnt;

    always @(posedge clk) begin
        if (!reset_n) state <= IDLE;
        else state <= next;
    end

    always @(*) begin
        next = state;
        case (state)
            IDLE: next = btn ? COUNT : IDLE;
            COUNT: begin
                if (!btn) next = IDLE;
                else next = (cnt == MAX_COUNT - 1) ? WAIT : COUNT;
            end
            WAIT: next = btn ? WAIT : IDLE;
            default: next = IDLE;
        endcase
    end


    always @(posedge clk) begin
        if (!reset_n | state != next) cnt <= {MAX_COUNT_BITS{1'b0}};
        else if (state == COUNT) cnt <= cnt + ONE;
    end
    
    assign held = (state == COUNT) & btn & (cnt == MAX_COUNT - 1);
endmodule
