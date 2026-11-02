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
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid),
        .rx_parsed_data(rx_parsed_data),
        .msg_valid(msg_valid)
    );

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(rx_parsed_data === '0);
        assert(msg_valid === '0);
        reset_n = '1;
    endtask


    function logic [DIGITS-1:0][DATA_WIDTH-1:0] hex_to_ascii(input logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] x);
        logic [DIGITS-1:0][DATA_WIDTH-1:0] temp;
        temp[2] = "0" + x / 100;
        temp[1] = "0" + (x/10) % 10;
        temp[0] = "0" + x % 10;
        return temp;
    endfunction

    function packet_cfg_t convert_parsed_to_packet(input logic [2:0][DIGITS-1:0][DATA_WIDTH-1:0] x);
        return {"{", pkt_data.r , x[2], ",", pkt_data.c , x[1], ",", pkt_data.v , x[0], "}"};
    endfunction

    function packet_cfg_t full_conversion_to_packet(input rx_parsed_t x);
        logic [DIGITS-1:0][DATA_WIDTH-1:0] row,col,val;
        row = hex_to_ascii(x.row_index);
        col = hex_to_ascii(x.col_index);
        val = hex_to_ascii(x.pixel_value);
        return convert_parsed_to_packet({row, col, val});
    endfunction

    task drive_pkt_data(input packet_cfg_t pkt);
        $display("Time: %0t | TASK: Drive pkt_data with: %h", $time, pkt);
        pkt_data = pkt;
    endtask;

    task drive_pkt_valid();
        $display("Time: %0t | TASK: Drive pkt_valid to 1 cycle", $time);
        pkt_valid = '1; #(CLK_PERIOD);
        pkt_valid = '0;
    endtask


    task drive_flow (input packet_cfg_t pkt);
        drive_pkt_data(pkt);
        drive_pkt_valid();
        assert(msg_valid === '1);
        assert(pkt_data === full_conversion_to_packet(rx_parsed_data));
        #(CLK_PERIOD);
    endtask

    task drive_false_flow(input packet_cfg_t pkt);
        rx_parsed_t temp;
        temp = rx_parsed_data;
        drive_pkt_data(pkt);
        drive_pkt_valid();
        assert(msg_valid === '0);
        assert(rx_parsed_data === temp);
        #(CLK_PERIOD);
    endtask


    initial begin
        reset_dut();

        // First check regular
        drive_flow("{R123,C045,V200}");
        drive_flow("{R255,C255,V255}");
        
        drive_false_flow("{A111,B222,X444}");

        drive_false_flow("{R256,C000,V000}");
        drive_false_flow("{R000,C256,V000}");
        drive_false_flow("{R000,C000,V256}");

        drive_flow("{r005,c050,v055}");
        drive_flow("{R123,c089,V111}");
        
        drive_false_flow("{R123;C045,V200}");

        $finish;


    end




endmodule
