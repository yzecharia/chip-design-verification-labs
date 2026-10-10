`timescale 1ns / 1ps


module chip_top(
    input clk, reset_n, 
    input uart_rx_line,
    input [15:0] switch,
    input [4:0] button,
    output uart_tx_line,
    output [15:0] led
    );
    
    wire [7:0] rx_data, tx_data;
    wire rd_en, rdy_for_rd;
    wire wr_en, busy;
    
    uart_rx uart_rx_i (
        .clk(clk),
        .reset_n(reset_n),
        .rx_data_line(uart_rx_line),
        .rd_en(rd_en),
        .rdy_for_rd(rdy_for_rd),
        .rx_data_out(rx_data)
    );
    
    uart_tx uart_tx_i(
        .clk(clk),
        .reset_n(reset_n),
        .tx_data_in(tx_data),
        .wr_en(wr_en),
        .busy(busy),
        .tx_data_line(uart_tx_line)
    );
    
endmodule
