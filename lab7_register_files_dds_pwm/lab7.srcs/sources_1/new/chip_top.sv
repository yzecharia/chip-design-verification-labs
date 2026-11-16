import lab7_pkg::*;
import led_rgf_pkg::*;
import pwm_rgf_pkg::*;
import sys_rgf_pkg::*;
import cnt_rgf_pkg::*;
`include "lab7_definitions.svh"

module chip_top #(
    parameter BAUD_RATE = `BAUD_RATE,
    parameter DEB_COUNT = `DEB_COUNT,
    parameter DISPLAY_RR = `DISPLAY_RR
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

    // sw reset and enable from sys_rgf
    logic sw_rst, en;
    logic sys_reset_n; assign sys_reset_n = reset_n & !sw_rst;

    // buttons are ignored when the chip is disabled
    btn_ctf_t io_en; assign io_en = en ? io_d : '0;

    //rx_phy
    logic [DATA_WIDTH-1:0] data_rx;
    logic done_rx;
    rx_phy #(.BAUD_RATE(BAUD_RATE)) rx_phy_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .rx(rx),
        .data(data_rx),
        .done(done_rx)
    );

    //rx_mac
    packet_cfg_t pkt_data;
    logic pkt_valid;
    rx_mac rx_mac_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .done(done_rx),
        .data_in(data_rx),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid)
    );

    //parser
    parsed_msg_t msg;
    parser parser_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid),
        .msg(msg)
    );

    //reg_interconnect
    logic wen, ren;
    logic [RGF_ADDR_WIDTH-1:0] addr;
    logic [RGF_DATA_WIDTH-1:0] wdata;
    logic [RGF_NUM-1:0] cs_one_hot;
    logic [RGF_DATA_WIDTH-1:0] led_rdata, pwm_rdata, cnt_rdata, sys_rdata;
    led_rgf_msg_t led_rgf_msg;
    tx_mac_in_t tx_data;
    logic msb_addr_err;
    reg_interconnect reg_interconnect_i(
        .msg(msg),
        .led_rdata(led_rdata),
        .pwm_rdata(pwm_rdata),
        .cnt_rdata(cnt_rdata),
        .sys_rdata(sys_rdata),
        .led_ctrl(led_rgf_msg.led_ctrl),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .cs_one_hot(cs_one_hot),
        .tx_data(tx_data),
        .msb_addr_err(msb_addr_err)
    );

    //selector
    logic pc_led_update;
    leds_cfg_t leds_out;
    selector_data_t sel_out;
    selector selector_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .btn_in(io_en),
        .led_rgf_msg(led_rgf_msg),
        .pc_led_update(pc_led_update),
        .leds_out(leds_out),
        .sel_out(sel_out)
    );
    assign led = en ? leds_out : '0;

    //led_rgf
    logic pattern_change;
    led_rgf led_rgf_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .select_in(sel_out),
        .cs(cs_one_hot[LED_RGF_ADDR]),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .rdata(led_rdata),
        .led_rgf_msg(led_rgf_msg),
        .pc_led_update(pc_led_update),
        .pattern_change(pattern_change)
    );

    //pwm_rgf
    pwm_rgf_msg_t pwm_rgf_msg;
    pwm_rgf pwm_rgf_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .cs(cs_one_hot[PWM_RGF_ADDR]),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .rdata(pwm_rdata),
        .pwm_rgf_msg(pwm_rgf_msg)
    );

    //cnt_rgf
    logic tx_msg_sent;
    cnt_rgf cnt_rgf_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .cs(cs_one_hot[CNT_RGF_ADDR]),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .msg(msg),
        .tx_msg_sent(tx_msg_sent),
        .rdata(cnt_rdata)
    );

    //sys_rgf - gets only the button reset, so the sw reset pulse is a full clock
    sys_rgf sys_rgf_i(
        .clk(clk),
        .reset_n(reset_n),
        .cs(cs_one_hot[SYS_RGF_ADDR]),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .msb_addr_err(msb_addr_err),
        .rdata(sys_rdata),
        .sw_rst(sw_rst),
        .en(en)
    );

    //display_ctrl
    display_cfg_t disp_cfg;
    display_ctrl #(.DISPLAY_RR(DISPLAY_RR)) display_ctrl_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .led_17_16(sel_out.display_led),
        .display_pixel(sel_out.led_value),
        .display_out(disp_cfg)
    );
    // anodes are active low - all 1 turns the display off
    assign an = en ? disp_cfg.an : '1;
    assign seg = disp_cfg.seg;
    assign dp = disp_cfg.dp;

    //led_src_mux
    logic wrap_cnt;
    corrected_pixel_t [1:0] led_val;
    led_src_mux led_src_mux_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .led16(led_rgf_msg.led16_value),
        .led17(led_rgf_msg.led17_value),
        .wrap_cnt(wrap_cnt),
        .pwm_msg(pwm_rgf_msg),
        .pattern(led_rgf_msg.led_pattern),
        .pattern_change(pattern_change),
        .led_ctrl(led_rgf_msg.led_ctrl),
        .led_val(led_val)
    );

    scaled_val_t [RGB_LED_NUM-1:0] scaled_vals;
    scale_cluster scale_cluster_i(
        .led_val(led_val),
        .pwm_cfg(pwm_rgf_msg.pwm_cfg),
        .scaled_vals(scaled_vals)
    );

    logic [CH_NUM-1:0] pwm_signals_16, pwm_signals_17;
    pwm_cluster pwm_cluster_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .pwm_cfg(pwm_rgf_msg.pwm_cfg),
        .scaled_vals(scaled_vals),
        .pwm_signals_16(pwm_signals_16),
        .pwm_signals_17(pwm_signals_17),
        .wrap_cnt(wrap_cnt)
    );
    assign {led16_r, led16_g, led16_b} = en ? pwm_signals_16 : '0;
    assign {led17_r, led17_g, led17_b} = en ? pwm_signals_17 : '0;

    //tx_mac
    logic done, tx_start;
    logic [DATA_WIDTH-1:0] drive_data;
    tx_mac tx_mac_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .done(done),
        .tx_in(tx_data),
        .drive_data(drive_data),
        .tx_start(tx_start),
        .tx_msg_sent(tx_msg_sent)
    );

    //tx_phy
    tx_phy #(.BAUD_RATE(BAUD_RATE)) tx_phy_i(
        .clk(clk),
        .reset_n(sys_reset_n),
        .start(tx_start),
        .data(drive_data),
        .tx(tx),
        .done(done)
    );

endmodule
