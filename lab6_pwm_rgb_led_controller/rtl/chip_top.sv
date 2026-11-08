import lab6_pkg::*;
`include "lab6_definitions.svh"

module chip_top #(
    parameter BAUD_RATE = `BAUD_RATE,
    parameter DEB_COUNT = `DEB_COUNT,
    parameter DISPLAY_RR = `DISPLAY_RR,
    parameter int SLOTS = `SLOTS
) (
    input logic clk, cpu_reset,
    input logic btnu, btnd, btnl, btnr, btnc,
    input logic rx,
    output logic tx,
    output logic [AN_WIDTH-1:0] an,
    output logic [SS_DIG_WIDTH-1:0] seg,
    output logic dp,
    output logic [15:0] led,
    output logic led16_r, led16_g, led16_b,
    output logic led17_r, led17_g, led17_b
);

    btn_ctf_t io_in; assign io_in = {btnu, btnd, btnl, btnr, btnc};

    // debounce
    logic reset_n;
    btn_ctf_t io_d;
    debounce_cluster #(.DEB_COUNT(DEB_COUNT)) debounce_cluster_i(
        .clk(clk),
        .cpu_reset(cpu_reset),
        .io_in(io_in),
        .io_d(io_d),
        .cpu_reset_d(reset_n)
    );

    //rx_phy
    logic [DATA_WIDTH-1:0] data_rx;
    logic done_rx;
    rx_phy #(.BAUD_RATE(BAUD_RATE)) rx_phy_i(
        .clk(clk),
        .reset_n(reset_n),
        .en(1'b1),
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
    pixel_parsed_t pixel_parsed_data;
    logic led_parsed_data;
    logic pixel_valid, led_valid;
    parser parser_i(
        .clk(clk),
        .reset_n(reset_n),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid),
        .pixel_parsed_data(pixel_parsed_data),
        .led_parsed_data(led_parsed_data),
        .pixel_valid(pixel_valid),
        .led_valid(led_valid)
    );

    //selector
    pixel_parsed_t display_pixel, pwm_pixel;
    logic pwm_new_data, pwm_led, display_led;
    leds_cfg_t leds_out;
    selector selector_i(
        .clk(clk),
        .reset_n(reset_n),
        .btn_in(io_d),
        .parsed_pixel_value(pixel_parsed_data),
        .parsed_led_value(led_parsed_data),
        .pixel_valid(pixel_valid),
        .led_valid(led_valid),
        .display_pixel(display_pixel),
        .pwm_pixel(pwm_pixel),
        .pwm_new_data(pwm_new_data),
        .pwm_led(pwm_led),
        .display_led(display_led),
        .leds_out(leds_out)
    );
    assign led = leds_out;

    //display_ctrl
    display_cfg_t disp_cfg;
    display_ctrl #(.DISPLAY_RR(DISPLAY_RR)) display_ctrl_i(
        .clk(clk),
        .reset_n(reset_n),
        .led_17_16(display_led),
        .display_pixel(display_pixel),
        .display_out(disp_cfg)
    );
    assign {an, seg, dp} = disp_cfg;

    //gemma_correction
    corrected_pixel_t corrected_pixel;
    gemma_correction gemma_correction_i(
        .pixel_in(pwm_pixel),
        .pixel_out(corrected_pixel)
    );

    //cie_scaling
    localparam int SLOTS_WIDTH = $clog2(SLOTS);
    logic [2:0][SLOTS_WIDTH-1:0] cie_pixel;
    cie_scaling #(.SLOTS(SLOTS)) cie_scaling_i(
        .pixel_in(corrected_pixel),
        .pixel_out(cie_pixel)
    );

    //pwm_cluster
    logic [2:0] led16, led17;
    pwm_cluster #(.SLOTS(SLOTS)) pwm_cluster_i(
        .clk(clk),
        .reset_n(reset_n),
        .value(cie_pixel),
        .pwm_led(pwm_led),
        .led16(led16),
        .led17(led17)
    );
    assign {led16_r, led16_g, led16_b} = led16;
    assign {led17_r, led17_g, led17_b} = led17;

    //tx_mac
    logic done, tx_start;
    logic [DATA_WIDTH-1:0] drive_data;
    tx_mac #(.SLOTS(SLOTS)) tx_mac_i(
        .clk(clk),
        .reset_n(reset_n),
        .start(pwm_new_data),
        .done(done),
        .pixel_data(cie_pixel),
        .drive_data(drive_data),
        .tx_start(tx_start)
    );

    //tx_phy
    tx_phy #(.BAUD_RATE(BAUD_RATE)) tx_phy_i(
        .clk(clk),
        .reset_n(reset_n),
        .start(tx_start),
        .data(drive_data),
        .tx(tx),
        .done(done)
    );

endmodule
