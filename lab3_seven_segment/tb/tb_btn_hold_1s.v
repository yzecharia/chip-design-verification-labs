`timescale 1ns/1ps
module tb_btn_hold_1s (
);
    localparam MAX_TICK = 5;
    localparam MAX_COUNT = 2;
    localparam ONE_SEC_CYCLES = MAX_TICK * MAX_COUNT; // The cycles for an actual press
    localparam MIN_LATENCY = 1 + (MAX_COUNT-1)*MAX_TICK; // the fastes 2 ticks (witch is the count for a pulse) is if we start 1 cycle before the first tick  + the 5 cycles for the next tick
    localparam MAX_LATENCY = ONE_SEC_CYCLES; // the slowes 2 tick we can get is: we get a click just as the first tick is done (so 5 cycles to first tick) + another 5 cycles to the second tick
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n;
    reg tick;
    reg click;
    wire pressed_1s;
    reg expected_pressed;
    integer pass = 0, fail = 0;

    btn_hold_1s #(.MAX_COUNT(MAX_COUNT)) btn_hold_1s_i (clk, reset_n, click, tick, pressed_1s);

    task reset();
        begin
            reset_n = 1'b0; tick = 1'b0; click = 1'b0;
            repeat (2) @(negedge clk);
            reset_n = 1'b1;
        end
    endtask

    task wait_posedge();
        begin
            @(posedge clk); #1;
        end
    endtask

    // synchronizer
    reg tb_sync0 = 0, tb_sync = 0;
    always @(posedge clk) begin
        tb_sync0 <= click;
        tb_sync <= tb_sync0;
    end

    // Tick gen
    integer count = 1;
    always @(posedge clk) begin
        if (reset_n) begin
            if (count == MAX_TICK) begin
                tick <= 1'b1;
                count <= 1;
            end else begin
                tick <= 1'b0;
                count <= count + 1;
            end
        end
    end

    // count the cycles the click is on to make sure the press is only after a correct amount of time
    integer cycles_clicked = 0;
    always @(posedge clk) cycles_clicked <= tb_sync ? cycles_clicked + 1 : 0;

    // count pulses per click and update how many cycles since the click
    integer pulses=0;
    integer cycles_since_click = 0;
    always @(posedge clk) begin
        if (pressed_1s == 1'b1) begin
            pulses <= pulses + 1;
            cycles_since_click <= cycles_clicked + 1;
        end
    end

    task drive_click(input integer cycles_to_wait);
        begin
            click = 1'b1;
            repeat (cycles_to_wait) wait_posedge(); click = 1'b0; 
            repeat (5) wait_posedge();

        end
    endtask

    // I drive a click for "cycles_to_wait" amount of time.
    // I want to check at the end of the click if my exp_pressed == pressed
    task check_pressed_pulse_once(input integer actual, input integer expected);
        reg res;
        begin
            if (reset_n) begin
                res = (actual == expected);
                $display("Time: %5d | Check if pressed_1s pulsed only once | actual=%0d | expected=%0d | %s", $time, actual, expected, (res) ? "PASS" : "FAIL");
                if (res) pass = pass + 1;
                else fail = fail + 1;
                pulses = 0;
            end
        end
    endtask

    // I want to check cycles since click to press_1s is correct
    task check_cycles_click_to_press(input integer actual);
        reg res;
        begin
            if (reset_n) begin
                res = (actual >= MIN_LATENCY) && (actual <= MAX_LATENCY);
                $display("Time: %5d | Check press_1s goes high after +-1sec | actual=%0d | min=%0d | max=%0d | %s", $time, actual, MIN_LATENCY, MAX_LATENCY, res ? "PASS" : "FAIL");
                if (res) pass = pass + 1;
                else fail = fail + 1;
                cycles_since_click = 0;
            end
        end
    endtask

    integer j;
    initial begin
        reset();

        // short press
        drive_click(3);
        check_pressed_pulse_once(pulses, 0);

        //try to press 1 cycle under min_latency
        drive_click(MIN_LATENCY-1); // because sync has delay at start and end we need to when the actual click ends
        check_pressed_pulse_once(pulses, 0);

        drive_click(5*ONE_SEC_CYCLES);
        check_cycles_click_to_press(cycles_since_click);
        check_pressed_pulse_once(pulses, 1);

        // check all the phases of tick 0 - 5
        for (j = 0; j <= MAX_TICK; j = j + 1) begin
            repeat (j) wait_posedge();
            drive_click(ONE_SEC_CYCLES);
            check_cycles_click_to_press(cycles_since_click);
            check_pressed_pulse_once(pulses, 1); 
        end

        // click on off
        repeat (3) begin
            click = 1'b1; wait_posedge();
            click = 1'b0; wait_posedge();
        end
        drive_click(2*ONE_SEC_CYCLES);
        check_cycles_click_to_press(cycles_since_click);
        check_pressed_pulse_once(pulses, 1);

        if (fail == 0 && pass > 0) $display("Time: %5d | TEST PASS | %0d/%0d", $time, pass, pass + fail);
        else $display("Time: %5d | TEST FAIL | %0d/%0d", $time, pass, pass + fail);

        $finish();
    end

endmodule
