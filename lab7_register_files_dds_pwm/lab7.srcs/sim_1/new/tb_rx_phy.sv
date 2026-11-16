import lab7_pkg::*;
`include "lab7_definitions.svh"
module tb_rx_phy;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic rx = '1;
    logic [DATA_WIDTH-1:0] data;
    logic done;

    rx_phy dut (
        .clk(clk),
        .reset_n(reset_n),
        .rx(rx),
        .data(data),
        .done(done)
    );

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(data === '0);
        assert(done === '0);
        reset_n = '1;
    endtask

    function logic [FRAME_WIDTH-1:0] get_frame (input logic [DATA_WIDTH-1:0] data, input logic stop);
        return {stop, data, 1'b0};
    endfunction

    localparam BIT_WAIT_CYCLES = CLK_FREQ / `BAUD_RATE;
    localparam BIT_WAIT = BIT_WAIT_CYCLES * CLK_PERIOD;
    localparam MID_BIT_WAIT = BIT_WAIT / 2;
    localparam SYNC_WAIT = 3 * CLK_PERIOD; // From waves


    bit sent_frame;
    int cnt; // counts the done pulses of a frame, used by the tasks below
    task send_frame(input [DATA_WIDTH-1:0] d_in);
        logic [FRAME_WIDTH-1:0] frame;
        sent_frame = '1;
        frame = get_frame(d_in, 1'b1);
        $display("Time: %0t | TASK: Sending frame: %b", $time, frame);
        for (int i = 0; i < FRAME_WIDTH; i++) begin
            $display("Time: %0t | TASK: Sending bit[%0d] | rx = %b", $time, i, frame[i]);
            rx = frame[i];
            if (i == FRAME_WIDTH-1) begin
                #(MID_BIT_WAIT + SYNC_WAIT);
                assert(done);
                assert(data === d_in);
                #(BIT_WAIT - (MID_BIT_WAIT + SYNC_WAIT));
            end else #(BIT_WAIT);
        end
        sent_frame = '0;
        #(CLK_PERIOD);
    endtask

    task send_frame_bad_stop(input [DATA_WIDTH-1:0] d_in);
        logic [FRAME_WIDTH-1:0] frame;
        sent_frame = '1;
        frame = get_frame(d_in, 1'b0);
        $display("Time: %0t | TASK: Sending frame with stop = 0: %b", $time, frame);
        for (int i = 0; i < FRAME_WIDTH; i++) begin
            $display("Time: %0t | TASK: Sending bit[%0d] | rx = %b", $time, i, frame[i]);
            rx = frame[i];
            #(BIT_WAIT);
        end
        assert(cnt === 0) else $error("Time: %0t | ERROR: done with stop = 0", $time);
        sent_frame = '0;
        rx = '1;
        #(BIT_WAIT);
    endtask

    initial begin
        reset_dut();
        #(BIT_WAIT);
        send_frame(8'hA5);
        send_frame(8'h5A);
        send_frame_bad_stop(8'h3C);
        rx = '0; #(BIT_WAIT / 4);
        rx = '1; #(BIT_WAIT * FRAME_WIDTH);
        send_frame(8'hFF);
        send_frame(8'h00);

        $finish;
    end
    
    property p_done_one_cyle;
        @(posedge clk)
        disable iff(!reset_n)
        ($past(done)) |-> (!done);
    endproperty
    assert property(p_done_one_cyle);

    // done once per frame

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) cnt <= '0;
        else if (sent_frame & done) cnt <= cnt + 1;
        else if (!sent_frame) cnt <= '0; 
        assert(cnt <= 1);
    end

    property p_done_low_not_in_frame;
        @(posedge clk)
        disable iff(!reset_n)
        (!sent_frame) |-> (done == '0);
    endproperty
    assert property(p_done_low_not_in_frame);




endmodule
