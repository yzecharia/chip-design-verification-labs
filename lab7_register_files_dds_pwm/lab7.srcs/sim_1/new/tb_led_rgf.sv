import lab7_pkg::*;
import led_rgf_pkg::*;

module tb_led_rgf;

    timeunit 1ns;
    timeprecision 1ps;

    bit clk = 1'b0;
    always #5 clk = !clk;

    logic reset_n;
    selector_data_t select_in; // uses btnc, display_led, led_value
    logic cs, wen, ren;
    logic [RGF_ADDR_WIDTH-1:0] addr;
    logic [RGF_DATA_WIDTH-1:0] wdata, rdata;
    led_rgf_msg_t led_rgf_msg;
    logic pc_led_update;
    logic pattern_change;

    led_rgf led_rgf_i (
        .clk(clk),
        .reset_n(reset_n),
        .select_in(select_in),
        .cs(cs),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .led_rgf_msg(led_rgf_msg),
        .pc_led_update,
        .pattern_change(pattern_change)
    );

    typedef struct packed {
        logic cs;
        logic wen;
        logic [RGF_ADDR_WIDTH-1:0] addr;
        logic [RGF_DATA_WIDTH-1:0] wdata;
    } write_msg_t;
    typedef struct packed {
        logic cs;
        logic ren;
        logic [RGF_ADDR_WIDTH-1:0] addr;
    } read_msg_t;


    bit actual_display_led;
    led_value_t actual_led_val;
    led_value_t [1:0] prev_led_value;
    led_rgf_msg_t exp_led_rgf_msg;
    led_rgf_msg_t prev_msg;


    task reset_dut();
        reset_n = '0; actual_display_led = '0; actual_led_val = '0; cs = '0; wen = '0; ren = '0; 
        addr = '0; wdata = '0; select_in = '0;
        repeat (3) @(posedge clk);
        assert(rdata === '0) else $error("Time: %0t | ERROR: Invalid rdata reset value", $time);
        assert(led_rgf_msg.led_ctrl === 6'b000001) 
                else $error("Time: %0t | ERROR: Invalid led_ctrl reset value", $time);
        assert(led_rgf_msg.led_pattern === 2'b00)
                else $error("Time: %0t | ERROR: Invalid led_pattern reset value", $time);
        assert(led_rgf_msg.led16_value === 24'h000000)
                else $error("Time: %0t | ERROR: Invalid led16_value reset value", $time);
        assert(led_rgf_msg.led17_value === 24'h000000)
                else $error("Time: %0t | ERROR: Invalid led17_value reset value", $time);  
        assert(led_rgf_i.led_status === 1'b0)
                else $error("Time: %0t | ERROR: Invalid led_status reset value", $time);    
        assert(pc_led_update === 1'b0)
                else $error("Time: %0t | ERROR: Invalid pc_led_update reset value", $time);
        assert(pattern_change === 1'b0)
                else $error("Time: %0t | ERROR: Invalid pattern_change reset value", $time);
        reset_n <= '1;
    endtask

    task set_select_in (input logic display_led, input led_value_t led_val);
        select_in.display_led = display_led;
        select_in.led_value = led_val;
    endtask

    task drive_btnc_press();
        @(posedge clk);
        select_in.btnc <= '1;
        prev_led_value <= {led_rgf_msg.led17_value, led_rgf_msg.led16_value};  
        @(posedge clk);
        select_in.btnc <= '0; @(posedge clk);
        //check
        assert((led_rgf_msg.led_ctrl.select !== 2'b00) & (led_rgf_msg.led_ctrl.select !== 2'b11))
                 else $error("Time: %0t | ERROR: led_ctrl.select has invalid value: %b", $time, led_rgf_msg.led_ctrl.select);
        actual_display_led = select_to_display_led(led_rgf_msg.led_ctrl.select);
        actual_led_val = get_led_value(actual_display_led);
        assert(actual_display_led === select_in.display_led)
                else $error("Time: %0t | ERROR: display_led didnt update properly after write", $time);
        assert(prev_led_value[!actual_display_led] === get_led_value(!actual_display_led))
                 else $error("Time: %0t | ERROR: Non selected led changed value after write", $time);
        assert(actual_led_val === select_in.led_value)
                else $error("Time: %0t | ERROR: Selected led did not update value properly after wirte", $time);
    endtask

    task drive_write_cmd(input write_msg_t msg);
        ren = '0;
        @(posedge clk);
        exp_led_rgf_msg = led_rgf_msg;
        {cs, wen, addr, wdata} <= msg; @(posedge clk);
        {cs, wen} <= '0; @(posedge clk);
        check_led_rgf_msg(msg, exp_led_rgf_msg);
    endtask 

    task check_led_rgf_msg(input write_msg_t msg, input led_rgf_msg_t exp);
        bit ctrl_sel_err;
        bit pattern_err;
        ctrl_sel_err = (msg.addr == LED_CTRL_ADDR) & ((msg.wdata[SELECT_STOP_BIT:SELECT_START_BIT] == 2'b00) | (msg.wdata[SELECT_STOP_BIT: SELECT_START_BIT] == 2'b11));
        pattern_err = (msg.addr == LED_PATTERN_ADDR) & (msg.wdata[LED_PATTERN_STOP_BIT: LED_PATTERN_START_BIT] == 2'b11);
        if (msg.cs & msg.wen)
            case (msg.addr)
                LED_CTRL_ADDR: if (!ctrl_sel_err) exp.led_ctrl = msg.wdata[LED_CTRL_STOP_BIT: LED_CTRL_START_BIT];
                LED_PATTERN_ADDR: if(!pattern_err) exp.led_pattern = msg.wdata[LED_PATTERN_STOP_BIT: LED_PATTERN_START_BIT];
                LED16_VALUE_ADDR: exp.led16_value = msg.wdata[LED16_VALUE_STOP_BIT: LED16_VALUE_START_BIT];
                LED17_VALUE_ADDR: exp.led17_value = msg.wdata[LED17_VALUE_STOP_BIT: LED17_VALUE_START_BIT];
                default: exp = exp;
            endcase
        assert(exp.led_ctrl === led_rgf_msg.led_ctrl) else $error("Time %0t | ERROR: Write to led_ctrl not working", $time);
        assert(exp.led_pattern === led_rgf_msg.led_pattern) else $error("Time: %0t | ERROR: Write to led_pattern not working", $time);
        assert(exp.led16_value === led_rgf_msg.led16_value) else $error("Time: %0t | ERROR: Write to led16_value not working", $time);
        assert(exp.led17_value === led_rgf_msg.led17_value) else $error("Time: %0t | ERROR: Write to led17_value not working", $time);
    endtask

    task drive_read_cmd(input read_msg_t msg);
        wen = '0;
        @(posedge clk);
        prev_msg = led_rgf_msg;
        {cs, ren, addr} <= msg; @(posedge clk);
        if (!(msg.addr == LED_STATUS_ADDR))
            check_read(msg, prev_msg);
        {cs, ren} <= '0; @(posedge clk);
    endtask

    task check_read(input read_msg_t msg, input led_rgf_msg_t prev);
        logic [RGF_DATA_WIDTH-1:0] exp;
        exp = '0;
        if (msg.ren & msg.cs)
            case(msg.addr)
                LED_CTRL_ADDR: exp = prev.led_ctrl;
                LED_PATTERN_ADDR: exp = prev.led_pattern;
                LED16_VALUE_ADDR: exp = prev.led16_value;
                LED17_VALUE_ADDR: exp = prev.led17_value;
                default: ;
            endcase
        assert(rdata === exp) else $error("Time: %0t | ERROR: Read not working at address: %h", $time, msg.addr);
    endtask

    function bit select_to_display_led(input logic [1:0] sel);
        return (sel == LED17_SEL_VAL);
    endfunction

    function led_value_t get_led_value(input logic display_led);
        return (display_led) ? led_rgf_msg.led17_value : led_rgf_msg.led16_value;
    endfunction


    property p_pc_led_update_pulse;
        @(posedge clk)
        disable iff(!reset_n)
        (pc_led_update) |=> (pc_led_update === 0);
    endproperty

    property p_pc_led_update_rise_condition;
        @(posedge clk)
        disable iff(!reset_n)
        (cs && wen && !select_in.btnc &&
        (((addr == LED_CTRL_ADDR) && 
        ((wdata[SELECT_STOP_BIT:SELECT_START_BIT] == LED16_SEL_VAL) || 
        (wdata[SELECT_STOP_BIT:SELECT_START_BIT] == LED17_SEL_VAL))) || 
        (addr == LED16_VALUE_ADDR) || (addr == LED17_VALUE_ADDR))) |=> pc_led_update;
    endproperty

    property p_led_status_rise_condition;
        @(posedge clk)
        disable iff(!reset_n)
        ((wen | ren) & cs & (addr > LED_STATUS_ADDR)) |=> led_rgf_i.led_status;
    endproperty

    property p_led_status_fall_condition;
        @(posedge clk)
        disable iff(!reset_n)
        (cs & ren & (addr == LED_STATUS_ADDR)) |=> !led_rgf_i.led_status;
    endproperty

    assert property(p_pc_led_update_rise_condition) else $error("Time: %0t | pc_led_update signal no acting like a pule", $time);
    assert property(p_pc_led_update_pulse) else $error("Time: %0t | pc_led_update pulse on wrong condition", $time);
    assert property(p_led_status_rise_condition) else $error("Time: %0t | led_status high on wrong condition", $time);
    assert property(p_led_status_fall_condition) else $error("Time: %0t | led_status R0C mechanisim broken, low on wrong condition", $time);


    initial begin
        reset_dut();

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: LED16_VALUE_ADDR, wdata: 32'hFFAABBCC});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED16_VALUE_ADDR});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED17_VALUE_ADDR});

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: LED_CTRL_ADDR, wdata: 32'h00000032});
        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: LED_CTRL_ADDR, wdata: 32'h0000000F});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED_CTRL_ADDR});

        drive_write_cmd('{cs: 1'b0, wen: 1'b1, addr: LED17_VALUE_ADDR, wdata: 32'h00DEAD00});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED17_VALUE_ADDR});

        set_select_in(1'b1, 24'h445566);
        drive_btnc_press();
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED17_VALUE_ADDR});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED16_VALUE_ADDR});

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: LED_PATTERN_ADDR, wdata: 32'h00000001});
        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: LED_PATTERN_ADDR, wdata: 32'h00000001});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED_PATTERN_ADDR});

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: LED_PATTERN_ADDR, wdata: 32'h00000003});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED_PATTERN_ADDR});

        drive_write_cmd('{cs: 1'b1, wen: 1'b1, addr: 16'h0020, wdata: 32'h12345678});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED_STATUS_ADDR});
        drive_read_cmd('{cs: 1'b1, ren: 1'b1, addr: LED_STATUS_ADDR});

        reset_dut();

        repeat (2) @(posedge clk);
        $finish;
    end

endmodule
