`timescale 1ns/1ps
module tb_tick_gen (
);
    localparam MAX_TICK = 5;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n;
    wire tick;
    reg exp_tick;

    integer pass = 0, fail = 0;

    task reset ();
        begin
            @(negedge clk); reset_n = 1'b0; exp_tick = 1'b0;
            @(negedge clk); reset_n = 1'b1;
        end
    endtask

    tick_gen #(.MAX_TICK(MAX_TICK)) tick_gen_i (clk, reset_n, tick);

    integer cycles = 0;
    reg first_seen = 1'b0;
    always @(negedge clk) begin
        if (reset_n) begin
            if (tick) begin
                if (first_seen) begin
                    $display("Time: %5d | Check tick interval correct | actual=%d | expected=%d | %s", $time, cycles, MAX_TICK, (cycles == MAX_TICK) ? "PASS" : "FAIL");
                    if (cycles == MAX_TICK) pass = pass + 1;
                    else fail = fail + 1;
                end
                first_seen = 1'b1;
                cycles = 1;
            end else cycles = cycles + 1;
        end
    end

    initial begin
        reset();
        repeat (100) @(negedge clk);

        if (fail == 0 & pass > 0) $display("Time: %5d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %5d | TEST FAIL | %0d/%0d", $time, pass, pass + fail);

        $finish();
    end

endmodule
