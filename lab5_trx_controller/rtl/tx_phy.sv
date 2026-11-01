`include "lab5_definitions.svh"
import lab5_pkg::*;

module tx_phy 
#(
    parameter BAUD_RATE = `BAUD_RATE
) (
    input logic clk, reset_n, start, 
    input logic [DATA_WIDTH - 1:0] data,
    output logic tx, done
);

    tx_phy_state_t state, next;

    logic tick;
    baud_gen #(.BAUD_RATE(BAUD_RATE)) baud_gen_i (
        .clk(clk),
        .reset_n(reset_n),
        .en((state == TX_PHY_TRANSMIT)),
        .baud_tick(tick)
    );

    localparam FRAME_BITS_SIZE = $clog2(FRAME_WIDTH);
    localparam [FRAME_BITS_SIZE-1:0] ONE = 1;

    logic [FRAME_BITS_SIZE-1:0] cnt;
    logic [FRAME_WIDTH-1:0] sh_reg;

    assign done = (cnt == FRAME_WIDTH - 1) & tick;
    logic sh_cnt_en, load;
    assign sh_cnt_en = (state == TX_PHY_TRANSMIT) & tick;
    assign load = (state == TX_PHY_IDLE) & start;
    always_ff @(posedge clk) begin
        if (!reset_n) cnt <= '0;
        else if (done | (state == TX_PHY_IDLE)) cnt <= '0;
        else if (sh_cnt_en) cnt <= cnt + ONE;
    end

    always_ff @(posedge clk) begin
        if (!reset_n) sh_reg <= '1;
        else if (load) sh_reg <= {1'b1, data, 1'b0};
        else if (sh_cnt_en) sh_reg <= {1'b1, sh_reg[FRAME_WIDTH - 1:1]};
    end

    always_ff @(posedge clk) begin
        if (!reset_n) state <= TX_PHY_IDLE;
        else state <= next;
    end 

    always_comb begin 
        next = state;
        unique case(state)
            TX_PHY_IDLE: next = start ? TX_PHY_TRANSMIT : TX_PHY_IDLE;
            TX_PHY_TRANSMIT: next = done ? TX_PHY_IDLE : TX_PHY_TRANSMIT;
            default: next = state;
        endcase
    end

    assign tx = sh_reg[0];


endmodule
