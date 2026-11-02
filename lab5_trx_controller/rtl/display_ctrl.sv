import lab5_pkg::*;
`include "lab5_definitions.svh"
module display_ctrl #(
    parameter DISPLAY_RR = `DISPLAY_RR
) (
    input logic clk, reset_n,
    input rx_parsed_t rx_data, 
    input sw_cfg_t tx_data,
    input logic [ROW_SIZE_WIDTH-1:0] row_out,
    input logic rx_tx_mode,
    output display_cfg_t display_out
);

    // 1. tick gen for 500hz
    logic tick;
    baud_gen #(.BAUD_RATE(DISPLAY_RR)) display_tick_i (
        .clk(clk),
        .reset_n(reset_n),
        .en(1'b1),
        .baud_tick(tick)
    );

    // 2. rotate an 0 and 500hz rate
    logic [AN_WIDTH-1:0] an;
    always_ff @(posedge clk) begin
        if (!reset_n) an <= AN_RESET_VAL;
        else if (tick) an <= {an[AN_WIDTH-2:0], an[AN_WIDTH-1]};
    end

    // 3. feed an to rx_display and tx_display
    seven_segment_data_t rx_display_data, tx_display_data;
    rx_display rx_display_i (
        .rx_data(rx_data),
        .an(an),
        .rx_display_data(rx_display_data)
    );

    tx_display tx_display_i (
        .an(an),
        .tx_data(tx_data),
        .row_out(row_out),
        .tx_display_data(tx_display_data)
    );


    display_ctrl_data_t display_data;

    seven_segment_data_t data_mode;
    assign data_mode = rx_tx_mode ? rx_display_data : tx_display_data;


    seven_segment seven_segment_i (
        .ss_in(data_mode),
        .display_ctrl_data(display_data)
    );  

    assign display_out = {an, display_data};

endmodule
