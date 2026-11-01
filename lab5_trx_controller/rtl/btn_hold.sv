`include "lab5_definitions.svh"
module btn_hold #(parameter BTN_HOLD_COUNT = `BTN_HOLD_COUNT) (
    input logic clk, reset_n, btn, 
    output logic held
);
    import lab5_pkg::*;

    localparam BTN_COUNT_WIDTH = $clog2(BTN_HOLD_COUNT);
    localparam [BTN_COUNT_WIDTH-1:0] ONE = 1;
    logic [BTN_COUNT_WIDTH-1:0] cnt;
    logic cnt_max;
    assign cnt_max = cnt == BTN_HOLD_COUNT - 1;
    btn_state_t state, next;

    always_ff @(posedge clk) begin
        if (!reset_n) state <= BTN_IDLE;
        else state <= next;
    end

    always_comb begin
        next = state;
        unique case(state)
            BTN_IDLE: next = btn ? BTN_COUNT : BTN_IDLE;
            BTN_COUNT: next = (!btn) ? BTN_IDLE : (cnt_max ? BTN_WAIT : BTN_COUNT);
            BTN_WAIT: next = btn ? BTN_WAIT : BTN_IDLE;
            default: next = state;
        endcase
    end

    always_ff @(posedge clk) begin
        if (!reset_n) cnt <= '0;
        else if (state != next) cnt <= '0;
        else if (state == BTN_COUNT) cnt <= cnt + ONE;
    end

    assign held = (state == BTN_COUNT) & btn & cnt_max;

    

endmodule
