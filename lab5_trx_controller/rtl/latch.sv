import lab5_pkg::*;

module latch (
    input logic clk, reset_n, ready,
    input sw_cfg_t sw_d,
    input logic held,
    input logic rx_tx_mode,
    output sw_cfg_t sw_cfg,
    output logic transmit
);

    logic latch_en;
    assign latch_en = ready & held & !rx_tx_mode;

    always_ff @(posedge clk) begin
        if (!reset_n) {transmit, sw_cfg} <= '0;
        else if (latch_en) {transmit, sw_cfg} <= {1'b1, sw_d};
        else transmit <= '0;
    end

endmodule
