import lab5_pkg::*;
`include "lab5_definitions.svh"

module chip_top (
    input logic clk, cpu_reset,
    input logic [SW_WIDTH-1:0] sw,
    input logic btnc,
    input logic rx,
    output logic tx, 
    output logic [AN_WIDTH-1:0] an,
    output logic [SS_DIG_WIDTH-1:0] seg,
    output logic dp,
    output logic led0, led15
);

    `ifdef SIM
        initial $display("SIM mode: BAUD_RATE=%0d | DEB_COUNT=%0d | BTN_HOLD_COUNT=%0d | DELAY_50MS_VAL=%0d | DISPLAY_RR=%0d", BAUD_RATE, DEB_COUNT, BTN_HOLD_COUNT, DELAY_50MS_VAL, DISPLAY_RR);
    `endif 

    board_in_t io_in; assign io_in = {sw[SW_WIDTH-1], btnc, sw[SW_WIDTH-2:0]};

    // debounce
    logic reset_n;
    board_in_t io_d;
    debounce_top debounce_top_i(
        .clk(clk),
        .cpu_reset(cpu_reset),
        .io_in(io_in),
        .io_d(io_d),
        .cpu_reset_d(reset_n)
    );

    logic rx_tx_mode; assign rx_tx_mode = io_d.mode;

    // btn_hold
    logic held;
    btn_hold btn_hold_i(
        .clk(clk),
        .reset_n(reset_n),
        .btn(io_d.btnc),
        .held(held)
    );


    // latch
    logic transmit, ready;
    sw_cfg_t sw_cfg;
    latch latch_i(
        .clk(clk),
        .reset_n(reset_n),
        .ready(ready),
        .sw_d(io_d.cfg),
        .held(held),
        .rx_tx_mode(rx_tx_mode),
        .sw_cfg(sw_cfg),
        .transmit(transmit)
    );

    //tx_mac
    logic done, start;
    logic [DATA_WIDTH-1:0] drive_data;
    logic [ROW_SIZE_WIDTH-1:0] row_out;
    tx_mac tx_mac_i(
        .clk(clk),
        .reset_n(reset_n),
        .en(!rx_tx_mode),
        .sw_d(sw_cfg),
        .transmit(transmit),
        .done(done),
        .drive_data(drive_data),
        .start(start),
        .led0(led0),
        .row_out(row_out),
        .ready(ready)
    );

    //tx_phy
    tx_phy tx_phy_i(
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .data(drive_data),
        .tx(tx),
        .done(done)
    );

    //rx_phy
    logic [DATA_WIDTH-1:0] data_rx;
    logic done_rx;
    rx_phy rx_phy_i(
        .clk(clk),
        .reset_n(reset_n),
        .en(rx_tx_mode),
        .rx(rx),
        .data(data_rx),
        .done(done_rx)
    );

    //rx_mac
    packet_cfg_t pkt_data;
    logic pkt_valid;
    rx_mac rx_mac_i(
        .clk(clk),
        .reset_n(reset_n),
        .done(done_rx),
        .data_in(data_rx),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid)
    );

    //parser
    rx_parsed_t rx_parsed_data;
    parser parser_i(
        .clk(clk),
        .reset_n(reset_n),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid),
        .rx_parsed_data(rx_parsed_data)
    );

    //display_ctrl
    display_cfg_t disp_cfg;
    display_ctrl display_ctrl_i(
        .clk(clk),
        .reset_n(reset_n),
        .rx_data(rx_parsed_data),
        .tx_data(sw_cfg),
        .row_out(row_out),
        .rx_tx_mode(rx_tx_mode),
        .display_out(disp_cfg)
    );
    assign {an, seg, dp} = disp_cfg;
    assign led15 = rx_tx_mode;


endmodule
