import lab5_pkg::*;

module tb_tx_display;

    logic [AN_WIDTH-1:0] an = '0;
    sw_cfg_t tx_data = '0;
    logic [ROW_SIZE_WIDTH-1:0] row_out = '0;
    seven_segment_data_t tx_display_data;

    tx_display dut (
        .an(an),
        .tx_data(tx_data),
        .row_out(row_out),
        .tx_display_data(tx_display_data)
    );

   

    function logic [AN_WIDTH-1:0] get_an(input int i);
        return ~(1 << i);
    endfunction

    function sw_cfg_t load_tx_data(input size_cfg_t size, input delay_cfg_t delay, input logic [1:0][DIG_IN_WIDTH-1:0] data);
        return {size, delay, data};
    endfunction


    task test_drive(input size_cfg_t size, input delay_cfg_t delay, input logic [1:0][DIG_IN_WIDTH-1:0] data, input logic [ROW_SIZE_WIDTH-1:0] row);
        int i;
        for (i = 0; i < AN_WIDTH; i++) begin
            an = get_an(i);
            row_out = row;
            tx_data = load_tx_data(size, delay, data);
            #(CLK_PERIOD);
        end

    endtask

    int s, d;
    initial begin
        
        for (s = 0; s < 4; s++) begin
            for (d = 0; d < 4; d++) begin
                test_drive(size_cfg_t'(s), delay_cfg_t'(d), 8'hA5, (s+d));
            end
        end
        
        $finish;
    end


endmodule
