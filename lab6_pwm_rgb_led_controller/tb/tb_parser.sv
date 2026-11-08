import lab6_pkg::*;

module tb_parser;
    
    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    packet_cfg_t pkt_data = '0;
    logic pkt_valid = '0;
    pixel_parsed_t pixel_parsed_data;
    logic led_parsed_data;
    logic pixel_valid, led_valid;

    parser dut (
        .clk(clk),
        .reset_n(reset_n),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid),
        .pixel_parsed_data(pixel_parsed_data),
        .led_parsed_data(led_parsed_data),
        .pixel_valid(pixel_valid),
        .led_valid(led_valid)
    );

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(pixel_parsed_data === '0);
        assert(pixel_valid === '0);
        assert(led_parsed_data === '0);
        assert(led_valid === '0);
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
        return {"{", pkt_data.op_2 , x[2], ",", pkt_data.op_1 , x[1], ",", pkt_data.op_0 , x[0], "}"};
    endfunction

    function packet_cfg_t full_conversion_to_packet(input pixel_parsed_t x);
        logic [DIGITS-1:0][DATA_WIDTH-1:0] r,g,b;
        r = hex_to_ascii(x.value_2);
        g = hex_to_ascii(x.value_1);
        b = hex_to_ascii(x.value_0);
        return convert_parsed_to_packet({r, g, b});
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
        assert(pixel_valid === '1);
        assert(pkt_data === full_conversion_to_packet(pixel_parsed_data));
        #(CLK_PERIOD);
    endtask

    task drive_false_flow(input packet_cfg_t pkt);
        pixel_parsed_t temp;
        temp = pixel_parsed_data;
        drive_pkt_data(pkt);
        drive_pkt_valid();
        assert(pixel_valid === '0);
        assert(pixel_parsed_data === temp);
        #(CLK_PERIOD);
    endtask


    initial begin
        reset_dut();

        // First check regular
        drive_flow("{R123,G045,B200}");
        drive_flow("{R255,G255,B255}");
        
        drive_false_flow("{A111,B222,X444}");

        drive_false_flow("{R256,G000,B000}");
        drive_false_flow("{R000,G256,B000}");
        drive_false_flow("{R000,G000,B256}");

        drive_flow("{r005,g050,b055}");
        drive_flow("{R123,g089,B111}");

        $finish;


    end




endmodule
