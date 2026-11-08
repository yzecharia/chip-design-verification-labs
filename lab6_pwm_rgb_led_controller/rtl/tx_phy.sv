`include "lab6_definitions.svh"
import lab6_pkg::*;

module tx_phy 
#(
    parameter BAUD_RATE = `BAUD_RATE
) (
    input logic clk, reset_n, start, 
    input logic [DATA_WIDTH - 1:0] data,
    output logic tx, done
);

    tx_state_t state, next;

    logic tick;
    baud_gen #(.BAUD_RATE(BAUD_RATE)) baud_gen_i (
        .clk(clk),
        .reset_n(reset_n),
        .en((state == TX_TRANSMIT)),
        .baud_tick(tick)
    );

    localparam FRAME_BITS_SIZE = $clog2(FRAME_WIDTH);
    localparam [FRAME_BITS_SIZE-1:0] ONE = 1;

    logic [FRAME_BITS_SIZE-1:0] cnt;
    logic [FRAME_WIDTH-1:0] sh_reg;

    assign done = (cnt == FRAME_WIDTH - 1) & tick;
    logic sh_cnt_en, load;
    assign sh_cnt_en = (state == TX_TRANSMIT) & tick;
    assign load = (state == TX_IDLE) & start;
    always_ff @(posedge clk) begin
        if (!reset_n) cnt <= '0;
        else if (done | (state == TX_IDLE)) cnt <= '0;
        else if (sh_cnt_en) cnt <= cnt + ONE;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) sh_reg <= '1;
        else if (load) sh_reg <= {1'b1, data, 1'b0};
        else if (sh_cnt_en) sh_reg <= {1'b1, sh_reg[FRAME_WIDTH - 1:1]};
    end

    always_ff @(posedge clk) begin
        if (!reset_n) state <= TX_IDLE;
        else state <= next;
    end 

    always_comb begin 
        next = state;
        unique case(state)
            TX_IDLE: next = start ? TX_TRANSMIT : TX_IDLE;
            TX_TRANSMIT: next = done ? TX_IDLE : TX_TRANSMIT;
            default: next = state;
        endcase
    end

    assign tx = sh_reg[0];


endmodule
