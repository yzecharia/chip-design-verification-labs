import lab5_pkg::*;
`include "lab5_definitions.svh"

module tb_tx_mac;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic en = '0;
    sw_cfg_t sw_d = '0;
    logic transmit = '0;
    logic done;
    logic [DATA_WIDTH-1:0] drive_data;
    logic start, led0;
    logic [ROW_SIZE_WIDTH-1:0] row_out;
    logic ready;

    tx_mac dut (
        .clk(clk),
        .reset_n(reset_n),
        .en(en),
        .sw_d(sw_d),
        .transmit(transmit),
        .done(done),
        .drive_data(drive_data),
        .start(start),
        .led0(led0),
        .row_out(row_out),
        .ready(ready)
    );

    bit exp_led0;
    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert ((drive_data === '0) & (led0 === '0) & (start === '0) & (row_out === '0) & (ready === '1));
        reset_n = '1;
    endtask

    // acting like latch
    task send_data(input sw_cfg_t sw);
        $display("Time: %0t | TASK: Drive inputs: data=%b, size=%b, delay=%b", 
                            $time, sw.data, sw.size, sw.delay);
        {transmit, sw_d} = { 1'b1 , sw}; #(CLK_PERIOD);
        transmit = '0;
    endtask

    task en_dut(input logic e);
        $display("Time %0t | TASK: %s DUT", $time, e ? "Enable" : "Disable");
        en = e;
    endtask

    // the way i am going to check every byte is going to be like this:
    /*
        A counter the counts from zero to (ALL_BYTES_SIZE - 1).
        ALL_BYTES_SIZE is calculated like this:
            in every row their are n data bytes, (n-1) space bytes and 2 new line bytes
                in total n + (n-1) + 2 = 2n + 1
            in total their are n line too so:
                ALL_BYTES_SIZE = n * (2n + 1) | n = SIZE from sw_d
        
        now each placment of the byte has a specific data value:
                0       1       2       3       4
            0   data    space   data    /r      /n
            1   data    space   data    /r      /n

        from this example:
            1. last 2 col in a row always /r /n
            2. if not 2 last cols and col is even -> data
            3. if not 2 last cols and col is odd -> space
        
        To calculate the position of row and col of each bytes based on a running counter,
        I'll use: 
            - col = i % (2n + 1)
            - row = i / (2n + 1)
            * i is the running counter index

        since their are in total from 0 : (2n + 1 -1), (2n:0), col to count
        for i in range ALL_BYTES_SIZE
            row = i / 2n+1
            col = i % 2n+1
            if (col == 2n-1) exp_drive_data = /r
            if (col == 2n) exp_drive_data = /n
            if (col % 2 == 0) 
                exp_drive_data = data
                exp_led0 = !exp_led0
            else exp_drive_data = space
            assert(row === row_out) // row calculation is just row_out

           at the start i will have a exp_led0, that will reset on !resetn
           and have a:
           assert((even col) & led0 === exp_led0)

        counter counts on each posedge of start.
        And the counter needs to restart when i tell it (not on transmit because transmit doesnt mean new transmittion)
    */

    function int get_size(input size_cfg_t size);
        case(size)
            SIZE_1: get_size = SIZE_1_VAL;
            SIZE_32: get_size = SIZE_32_VAL;
            SIZE_128: get_size = SIZE_128_VAL;
            SIZE_256: get_size = SIZE_256_VAL;
            default: get_size = SIZE_1_VAL;
        endcase
    endfunction

    localparam MAX_SIZE = SIZE_256_VAL * (2 * SIZE_256_VAL + 1);
    logic [$clog2(MAX_SIZE)-1:0] byte_cnt;
    bit reset_byte_cnt;
    bit last_byte; assign last_byte = (byte_cnt == get_size(sw_d.size));
    logic [DATA_WIDTH - 1:0] exp_byte; assign exp_byte = get_expected_byte(byte_cnt, sw_d.data, get_size(sw_d.size));
    bit exp_led0_passive; assign exp_led0_passive = (is_data_byte(byte_cnt, get_size(sw_d.size))) ? !exp_led0 : exp_led0;
    always_ff @(posedge clk) begin
        if (!reset_n) begin 
            byte_cnt <= '0;
            exp_led0 <= '0;
        end
        else if (reset_byte_cnt | !en) byte_cnt <= '0;
        else if (start) begin
            //$display("Time: %0t| drive_data=%b | exp_drive_data=%b", $time, drive_data, exp_byte);
            assert(drive_data === exp_byte);
            assert(row_out === get_row(byte_cnt, get_size(sw_d.size)));
            byte_cnt <= byte_cnt + 1;
            if (is_data_byte(byte_cnt, get_size(sw_d.size))) exp_led0 <= exp_led0_passive;
            //$display("Time: %0t | led0=%b | exp_led0=%b", $time, led0, exp_led0);
            assert(led0 === exp_led0_passive);
        end
    end

    function logic [ROW_SIZE_WIDTH-1:0] get_row(input logic [$clog2(MAX_SIZE)-1:0] i, input int n);
        int col_size;
        col_size = 2*n + 1;
        return i / col_size;
    endfunction


    function bit is_data_byte(input logic [$clog2(MAX_SIZE)-1:0] i, input int n);
        int col;
        bit not_new_line;
        col = i % (2*n + 1);
        not_new_line = (col < 2*n-1);
        return (not_new_line) & (col%2 ==0);
    endfunction

    function logic [DATA_WIDTH-1:0] get_expected_byte (input logic [$clog2(MAX_SIZE)-1:0] idx, input logic [DATA_WIDTH-1:0] data, input int s);
        int col, col_size;
        col_size = (2 * s + 1);
        col = idx % col_size;
        if (col == col_size-2) return NEW_LINE_0_DATA;
        if (col == col_size-1) return NEW_LINE_1_DATA;
        if (col % 2 == 0) return data;
        else return SPACE_DATA;
    endfunction

    task wait_to_reset_byte_cnt();
        int size;
        size = get_size(sw_d.size);
        while(!ready) #(CLK_PERIOD);
        assert(byte_cnt == size * (2 * size + 1));
        reset_byte_cnt = 1; #(CLK_PERIOD);
        reset_byte_cnt = '0;
    endtask


    // need to make phy interaction for mac
    // phy:
    // when start goes up for one cycle,
    // after one (CLKS_PER_BITS * 10) mac gets a dont input,
    // to shorten the tb i will make (CLKS_PER_BIT * 10) 1 clk cycle.
    // added option to change the delay time
    logic start_state;
    logic [$clog2((CLK_FREQ/`BAUD_RATE)*10)-1:0] cnt;

    always_ff @(posedge clk) begin
        if (!reset_n) cnt <= '0;
        else if (!start_state) cnt <= '0;
        else cnt <= cnt + 1;
    end
    localparam DELAY_CYCLES = 1;
    assign done = (cnt == (DELAY_CYCLES - 1)) & start_state;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            start_state <= '0;
        end else if (start) start_state <= '1;
        else if (done) begin
            start_state <= '0;
        end
    end

    initial begin
        reset_dut();
    
        en_dut('1);
        send_data({SIZE_32, DELAY_0MS, 8'h41});
        wait_to_reset_byte_cnt();
        
        send_data({SIZE_128, DELAY_50MS, 8'hAA});
        wait_to_reset_byte_cnt();

        send_data({SIZE_256, DELAY_100MS, 8'hAA});
        wait_to_reset_byte_cnt();

        send_data({SIZE_1, DELAY_200MS, 8'hBB});
        wait_to_reset_byte_cnt();

        send_data({SIZE_128, DELAY_50MS, 8'hFF});
        #(((SIZE_128_VAL * (2 * SIZE_128_VAL + 1)) / 2) * CLK_PERIOD);
        en_dut(0); #(CLK_PERIOD)
        en_dut(1);

        send_data({SIZE_128, DELAY_50MS, 8'hA5});
        #(((SIZE_128_VAL * (2 * SIZE_128_VAL + 1)) / 2) * CLK_PERIOD);
        send_data({SIZE_128, DELAY_50MS, 8'hA5}); // sw_d has to stay the same during a run (latch functionality)
        wait_to_reset_byte_cnt();


        send_data({SIZE_1, DELAY_200MS, 8'h0D});
        wait_to_reset_byte_cnt();


        $finish;
    end

endmodule
