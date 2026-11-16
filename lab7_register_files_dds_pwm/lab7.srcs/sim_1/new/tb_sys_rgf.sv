import lab7_pkg::*;
import sys_rgf_pkg::*;

module tb_sys_rgf;
    timeunit 1ns;
    timeprecision 1ps;

    // clock - 100MHz, period of 10ns
    bit clk = '0;
    always #5 clk = !clk;

    // dut inputs and outputs
    logic reset_n = '0;
    logic cs = '0, wen = '0, ren = '0;
    logic [RGF_ADDR_WIDTH-1:0] addr = '0;
    logic [RGF_DATA_WIDTH-1:0] wdata = '0;
    logic msb_addr_err = '0;
    logic [RGF_DATA_WIDTH-1:0] rdata;
    logic sw_rst, en;

    // device under test
    sys_rgf dut (
        .clk(clk),
        .reset_n(reset_n),
        .cs(cs),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .msb_addr_err(msb_addr_err),
        .rdata(rdata),
        .sw_rst(sw_rst),
        .en(en)
    );

    // an offset that does not exist in the SYS RGF
    localparam [RGF_ADDR_WIDTH-1:0] BAD_ADDR = RGF_ADDR_WIDTH'(8);

    // sys_ctrl write values
    localparam [RGF_DATA_WIDTH-1:0] EN_OFF = 32'h0;
    localparam [RGF_DATA_WIDTH-1:0] EN_ON = 32'h1;
    localparam [RGF_DATA_WIDTH-1:0] RST_EN_OFF = 32'h2;
    localparam [RGF_DATA_WIDTH-1:0] RST_EN_ON = 32'h3;

    // sys_status read values
    localparam [RGF_DATA_WIDTH-1:0] ST_ADDR_ERR = 32'h1;
    localparam [RGF_DATA_WIDTH-1:0] ST_MSB_ADDR_ERR = 32'h2;
    localparam [RGF_DATA_WIDTH-1:0] ST_BOTH = 32'h3;

    // number of failed checks, used for the final PASS / FAIL report
    int errors = 0;

    // background monitor - counts for how many clocks sw_rst was high
    int sw_rst_cycles = 0;
    always @(posedge clk) begin
        if (sw_rst) sw_rst_cycles++;
    end

    // reset for one clock, the sw_rst monitor starts again from 0
    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        reset_n = '1;
        sw_rst_cycles = 0;
    endtask

    // write access for one clock
    task write_reg(input logic [RGF_ADDR_WIDTH-1:0] a, input logic [RGF_DATA_WIDTH-1:0] data);
        $display("Time: %0t | TASK: Write %h to offset %0d", $time, data, a);
        cs = '1; wen = '1; addr = a; wdata = data; #(CLK_PERIOD);
        cs = '0; wen = '0; wdata = '0;
    endtask

    // rdata is sampled while ren is high, before the clock edge that clears sys_status
    task read_reg(input logic [RGF_ADDR_WIDTH-1:0] a, output logic [RGF_DATA_WIDTH-1:0] data);
        cs = '1; ren = '1; addr = a; #1;
        data = rdata; #(CLK_PERIOD - 1);
        cs = '0; ren = '0;
    endtask

    // reads a register and compares it with the expected value
    task check_reg(input logic [RGF_ADDR_WIDTH-1:0] a, input logic [RGF_DATA_WIDTH-1:0] exp, input string name);
        logic [RGF_DATA_WIDTH-1:0] data;
        read_reg(a, data);
        assert (data === exp) $display("Time: %0t | PASS: %s = %h", $time, name, data);
        else begin
            $error("%s = %h, expected %h", name, data, exp);
            errors++;
        end
    endtask

    // compares the en output with the expected value
    task check_en(input logic exp);
        assert (en === exp) $display("Time: %0t | PASS: en = %b", $time, en);
        else begin
            $error("en = %b, expected %b", en, exp);
            errors++;
        end
    endtask

    // waits until a pulse is over, then checks how many clocks sw_rst was high
    task check_sw_rst(input int exp_cycles);
        #(2 * CLK_PERIOD);
        assert (sw_rst_cycles == exp_cycles) $display("Time: %0t | PASS: sw_rst was high for %0d clocks", $time, sw_rst_cycles);
        else begin
            $error("sw_rst was high for %0d clocks, expected %0d", sw_rst_cycles, exp_cycles);
            errors++;
        end
        sw_rst_cycles = 0;
    endtask

    // error from reg_interconnect = msb_addr_err high for one clock (cs is 0 in this case)
    task pulse_msb_addr_err();
        $display("Time: %0t | TASK: msb_addr_err pulse", $time);
        msb_addr_err = '1; #(CLK_PERIOD);
        msb_addr_err = '0;
    endtask

    // properties that must hold in every scenario
    always @(posedge clk) begin
        if (reset_n) begin
            assert (rdata[RGF_DATA_WIDTH-1:2] === '0)
            else begin
                $error("rdata = %h, the unused bits are not 0", rdata);
                errors++;
            end
            if (!(cs && ren)) begin
                assert (rdata === '0)
                else begin
                    $error("rdata = %h when the RGF is not read", rdata);
                    errors++;
                end
            end
        end
    end

    // test scenarios
    initial begin
        // Scenario 1: after reset en is 1, sw_rst is 0 and sys_status is 0
        $display("Scenario 1 - reset values");
        reset_dut();
        check_en(1'b1);
        check_sw_rst(0);
        check_reg(SYS_CTRL_ADDR, EN_ON, "sys_ctrl");
        check_reg(SYS_STATUS_ADDR, '0, "sys_status");

        // Scenario 2: en follows the value written to sys_ctrl and can be read back
        $display("Scenario 2 - enable off and on");
        write_reg(SYS_CTRL_ADDR, EN_OFF);
        check_en(1'b0);
        check_reg(SYS_CTRL_ADDR, EN_OFF, "sys_ctrl");
        write_reg(SYS_CTRL_ADDR, EN_ON);
        check_en(1'b1);
        check_reg(SYS_CTRL_ADDR, EN_ON, "sys_ctrl");
        check_sw_rst(0);

        // Scenario 3: writing 1 to reset gives one clock of sw_rst, the reset bit always reads 0
        $display("Scenario 3 - sw reset");
        write_reg(SYS_CTRL_ADDR, RST_EN_ON);
        check_sw_rst(1);
        check_en(1'b1);
        check_reg(SYS_CTRL_ADDR, EN_ON, "sys_ctrl");
        write_reg(SYS_CTRL_ADDR, RST_EN_OFF);
        check_sw_rst(1);
        check_en(1'b0);
        write_reg(SYS_CTRL_ADDR, EN_ON);
        check_sw_rst(0);
        check_en(1'b1);

        // Scenario 4: read or write to a bad offset sets addr_err and does not change en or sw_rst
        $display("Scenario 4 - bad offset");
        check_reg(BAD_ADDR, '0, "bad offset");
        check_reg(SYS_STATUS_ADDR, ST_ADDR_ERR, "sys_status");
        check_reg(SYS_STATUS_ADDR, '0, "sys_status after read");
        write_reg(BAD_ADDR, RST_EN_OFF);
        check_sw_rst(0);
        check_en(1'b1);
        check_reg(SYS_STATUS_ADDR, ST_ADDR_ERR, "sys_status");

        // Scenario 5: msb_addr_err sets its own flag, both flags are kept and one read clears both
        $display("Scenario 5 - msb address error");
        pulse_msb_addr_err();
        check_reg(SYS_STATUS_ADDR, ST_MSB_ADDR_ERR, "sys_status");
        pulse_msb_addr_err();
        write_reg(BAD_ADDR, EN_OFF);
        check_reg(SYS_STATUS_ADDR, ST_BOTH, "sys_status");
        check_reg(SYS_STATUS_ADDR, '0, "sys_status after read");

        // Scenario 6: reset in the middle returns en to 1 and clears sys_status
        $display("Scenario 6 - reset in the middle");
        write_reg(SYS_CTRL_ADDR, EN_OFF);
        write_reg(BAD_ADDR, EN_OFF);
        pulse_msb_addr_err();
        reset_dut();
        check_en(1'b1);
        check_reg(SYS_CTRL_ADDR, EN_ON, "sys_ctrl");
        check_reg(SYS_STATUS_ADDR, '0, "sys_status");

        // final report
        if (errors == 0) $display("TEST PASSED");
        else $display("TEST FAILED - %0d errors", errors);
        $finish;
    end

endmodule