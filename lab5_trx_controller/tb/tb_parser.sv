import lab5_pkg::*;

module tb_parser;
    
    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    packet_cfg_t pkt_data = '0;
    logic pkt_valid = '0;
    rx_parsed_t rx_parsed_data;
    logic msg_valid;

    parser dut (
        .clk(clk),
        .reset_n(reset_n),
        .pkt_valid(pkt_valid),
        .rx_parsed_data(rx_parsed_data),
        .msg_valid(msg_valid)
    );

    task reset_dut();
        reset_n = '0; #(CLK_PERIOD);
        assert(rx_parsed_data === '0);
        assert(msg_valid === '0);
        reset_n = '1;
    endtask

    // rx_max (pkt) -> parser (parsered_data) -> tb (back to pkt and check if it is equal to pkt_data)
    

endmodule
