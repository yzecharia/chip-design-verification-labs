import lab5_pkg::*;

module tb_tx_phy;
    timeunit 1ns;
    timeprecision 1ps;
    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic start = '0;
    logic [DATA_WIDTH-1:0] data = '0;
    logic tx, done;

    tx_phy t_phy_i(
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .data(data),
        .tx(tx),
        .done(done)
    );

    // How many clks per bit?
    // CLK_FREQ / BAUD_RATE
    localparam CLKS_PER_BIT = CLK_FREQ / `BAUD_RATE;
    localparam BIT_WAIT = CLKS_PER_BIT * CLK_PERIOD;

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD); assert((tx === '1) & (done === '0));
        reset_n = '1;
    endtask

    logic [FRAME_WIDTH-1:0] frame;
    task send_data(input logic [DATA_WIDTH-1:0] data_2_drive);
        $display("Time: %0t | TASK: Send data: %b", $time, data_2_drive);
        data = data_2_drive; start = '1; #(CLK_PERIOD);
        start = '0;
        frame = {1'b1, data_2_drive, 1'b0};
        for (int i=0; i < FRAME_WIDTH; i++) begin
            if (i == 0) #(BIT_WAIT - 1*CLK_PERIOD); // To take in to consideration the first #(CLK_PERIOD) after start
            else #(BIT_WAIT);
            $display("Time: %0t | TASK: DUT_tx=%b, TB_tx=%b", $time, tx, frame[i]);
            assert(frame[i] === tx);
        end
        assert(done);
        #(CLK_PERIOD);
    endtask

    task check_idle(input int clk_cycles);
        $display("Time: %0t | TASK: Check it tx=1 while idle", $time);
        for (int i = 0; i < clk_cycles; i++) begin
            #(CLK_PERIOD);
            assert((tx === '1) & (done === '0));
        end
    endtask

    initial $monitor("Time: %0t | tx=%b | done=%b",
                        $time, tx, done);

    initial begin
        $display("Time: %0t | Reset DUT", $time);
        reset_dut();

        // Drive 0xA5;
        $display("Time: %0t | Driving: %b", $time, 8'hA5);
        send_data(8'hA5);

        // Drive 0x5A;
        $display("Time: %0t | Driving: %b", $time, 8'h5A);
        send_data(8'h5A);

        //Drive 0x00
        $display("Time: %0t | Driving: %b", $time, 8'h00);
        send_data(8'h00);

        //Drive 0xFF
        $display("Time: %0t | Driving: %b", $time, 8'hFF);
        send_data(8'hff);

        check_idle(100);

        $finish;
    end


    property p_load;
        @(posedge clk)
        disable iff(!reset_n)
        ($past(start)) |-> (t_phy_i.sh_reg == {1'b1, data, 1'b0});
    endproperty

    property p_tx_one_done;
        @(posedge clk)
        disable iff(!reset_n)
        ($past(done)) |-> (tx);
    endproperty

    assert property(p_load);
    assert property(p_tx_one_done);

endmodule
