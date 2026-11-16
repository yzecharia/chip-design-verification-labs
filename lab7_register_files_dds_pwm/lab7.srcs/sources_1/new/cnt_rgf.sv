import lab7_pkg::*;
import cnt_rgf_pkg::*;
module cnt_rgf (
    input logic clk, reset_n,
    input logic cs, wen, ren,
    input logic [RGF_ADDR_WIDTH-1:0] addr,
    input parsed_msg_t msg, // from parser, msg_valid is high for one clock
    input logic tx_msg_sent, // from tx_mac, high for one clock when a message is done
    output logic [RGF_DATA_WIDTH-1:0] rdata
);

    logic [CNT_WIDTH-1:0] rx_packet_cnt, tx_packet_cnt, color_msg_cnt, config_msg_cnt;
    cnt_status_t cnt_status;

    logic rx_inc;
    logic config_inc;
    logic color_inc;
    logic addr_err;
    logic clr_addr_err;
    
    assign config_inc = msg.msg_valid && (msg.msg_type != RGB_CMD);
    assign rx_inc = msg.msg_valid;
    assign color_inc = msg.msg_valid && (msg.msg_type == RGB_CMD);
    

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) rx_packet_cnt <= CNT_RX_PACKET_RESET_VAL[CNT_STOP_BIT:CNT_START_BIT];
        else if (rx_inc) rx_packet_cnt <= rx_packet_cnt + 1;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) tx_packet_cnt <= CNT_TX_PACKET_RESET_VAL[CNT_STOP_BIT:CNT_START_BIT];
        else if (tx_msg_sent) tx_packet_cnt <= tx_packet_cnt + 1;
    end

    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) color_msg_cnt <= CNT_COLOR_MSG_RESET_VAL[CNT_STOP_BIT:CNT_START_BIT];
        else if (color_inc) color_msg_cnt <= color_msg_cnt + 1;
    end

    always_ff @(posedge clk or negedge reset_n) begin 
        if (!reset_n) config_msg_cnt <= CNT_CONFIG_MSG_RESET_VAL[CNT_STOP_BIT:CNT_START_BIT];
        else if (config_inc) config_msg_cnt <= config_msg_cnt + 1;
    end

    // address decode - one select signal per register, addr_err_comb when no offset matches
    logic rx_packet_sel, tx_packet_sel, color_msg_sel, config_msg_sel, cnt_status_sel;
    logic addr_err_comb;

    always_comb begin : reg_addr_dec
        rx_packet_sel = '0;
        tx_packet_sel = '0;
        color_msg_sel = '0;
        config_msg_sel = '0;
        cnt_status_sel = '0;
        addr_err_comb = '0;
        unique case(addr)
            CNT_RX_PACKET_ADDR: rx_packet_sel = '1;
            CNT_TX_PACKET_ADDR: tx_packet_sel = '1;
            CNT_COLOR_MSG_ADDR: color_msg_sel = '1;
            CNT_CONFIG_MSG_ADDR: config_msg_sel = '1;
            CNT_STATUS_ADDR: cnt_status_sel = '1;
            default: addr_err_comb = '1;
        endcase
    end

    // cnt_status - set on access to a non-existing offset, cleared when cnt_status is read (R0C)

    assign addr_err = cs && (wen || ren) && addr_err_comb;
    assign clr_addr_err = cs && ren && cnt_status_sel;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) cnt_status <= CNT_STATUS_RESET_VAL[CNT_STATUS_STOP_BIT:CNT_STATUS_START_BIT];
        else if (addr_err) cnt_status <= 1'b1;
        else if (clr_addr_err) cnt_status <= '0;
    end

    // read mux - drives rdata with the selected register when the RGF is read
    always_comb begin
        rdata = '0;
        if (cs & ren) begin
            unique case(1'b1)
                rx_packet_sel: rdata = rx_packet_cnt;
                tx_packet_sel: rdata = tx_packet_cnt;
                color_msg_sel: rdata = color_msg_cnt;
                config_msg_sel: rdata = config_msg_cnt;
                cnt_status_sel: rdata = cnt_status;
                default: rdata = '0;
            endcase
        end
    end

endmodule