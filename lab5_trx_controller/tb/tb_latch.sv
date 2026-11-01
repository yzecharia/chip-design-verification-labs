import lab5_pkg::*;

module tb_latch;
    timeunit 1ns;
    timeprecision 1ps;
    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic ready = '0;
    sw_cfg_t sw_d = '0;
    logic held = '0;
    logic rx_tx_mode = '0;
    sw_cfg_t sw_cfg;
    logic transmit;

    latch latch_i(
        .clk(clk),
        .reset_n(reset_n),
        .ready(ready),
        .sw_d(sw_d),
        .held(held),
        .rx_tx_mode(rx_tx_mode),
        .sw_cfg(sw_cfg),
        .transmit(transmit)
    );

    initial $monitor("Time: %0t | sw_cfg=%b | transmit=%b",
                    $time, sw_cfg, transmit);

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert((!transmit) & (sw_cfg === '0));
        reset_n = '1;
    endtask

    task set_sw_d(input logic [11:0] sw_val);
        $display("Time: %0t | TASK: Set sw_d to: %b", $time, sw_val);
        sw_d = sw_val;
    endtask

    task set_mode(input logic mode);
        $display("Time: %0t | TASK: Set rx_tx_mode to: %s (%b)", $time, (mode) ? "RX" : "TX", mode);
        rx_tx_mode = mode;
    endtask

    task set_ready(input logic r);
        $display("Time: %0t | TASK: Set ready to: %b", $time, r);
        ready = r;
    endtask

    task set_held(input logic h);
        $display("Time: %0t | TASK: Set held to: %b", $time, h);
        held = h;
    endtask

    integer i;

    initial begin
        $display("Time: %0t | Reset DUT", $time);
        reset_dut(); 
        
        set_sw_d('1);

        for (i=0; i<2**3; i++) begin
            set_mode(i[2]);
            set_held(i[1]);
            set_ready(i[0]);
            #(CLK_PERIOD);
        end

        #(CLK_PERIOD);
        $finish;
    end


    property p_latch_en;
        @(posedge clk)
        disable iff(!reset_n)
        ($past(ready) & $past(held) & $past(!rx_tx_mode)) |-> (sw_cfg === sw_d);
    endproperty

    property p_reset_values;
        @(posedge clk)
        (!reset_n) |=> ({transmit, sw_cfg} === '0);
    endproperty

    assert property(p_latch_en);
    assert property(p_reset_values);


endmodule
