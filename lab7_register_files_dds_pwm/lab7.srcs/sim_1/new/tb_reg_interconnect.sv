import lab7_pkg::*;
import led_rgf_pkg::*;
import pwm_rgf_pkg::*;

module tb_reg_interconnect;

    // Fake clk for timing
    bit clk = 1'b0;
    always #5 clk = !clk;

    parsed_msg_t msg;
    logic [RGF_DATA_WIDTH-1:0] led_rdata, pwm_rdata, cnt_rdata, sys_rdata;
    led_ctrl_t led_ctrl;
    logic wen, ren;
    logic[RGF_ADDR_WIDTH-1:0] addr;
    logic [RGF_DATA_WIDTH-1:0] wdata;
    logic [RGF_NUM-1:0] cs_one_hot;
    tx_mac_in_t tx_data;
    logic msb_addr_err;

    reg_interconnect reg_interconnect_i (
        .msg(msg),
        .led_rdata(led_rdata),
        .pwm_rdata(pwm_rdata),
        .cnt_rdata(cnt_rdata),
        .sys_rdata(sys_rdata),
        .led_ctrl(led_ctrl),
        .wen(wen),
        .ren(ren),
        .addr(addr),
        .wdata(wdata),
        .cs_one_hot(cs_one_hot),
        .tx_data(tx_data),
        .msb_addr_err(msb_addr_err)
    );

    task reset_dut();
        msg = '0;
        led_ctrl = '0;
        led_ctrl.select = LED16_SEL_VAL;
        repeat(3) @(posedge clk);
    endtask

    typedef struct packed {
        logic wen, ren;
        logic [RGF_ADDR_WIDTH-1:0] addr;
        logic [RGF_DATA_WIDTH-1:0] wdata;
        logic [RGF_NUM-1:0] cs_one_hot;
        tx_mac_in_t tx_data;
        logic msb_addr_err;
    } exp_t;

    task drive_msg(input parsed_msg_t m);
        exp_t exp;
        $display("Time: %0t | Driving msg: %p", $time, m);
        @(posedge clk);
        msg <= m;
        @(negedge clk);
            // check here
        exp = predict(msg);
        assert(wen === exp.wen) else $error("Time: %0t | ERROR: Invalid wen | actual=%0b | expected=%0b", $time, wen, exp.wen);
        assert(ren === exp.ren) else $error("Time: %0t | ERROR: Invalid ren | actual=%0b | expected=%0b", $time, ren, exp.ren);
        assert(addr === exp.addr) else $error("Time: %0t | ERROR: Invalid addr | actual=%0h | expected=%0h", $time, addr, exp.addr);
        assert(wdata === exp.wdata) else $error("Time: %0t | ERROR: Invalid wdata | actual=%0h | expected=%0h", $time, wdata, exp.wdata);
        assert(cs_one_hot === exp.cs_one_hot) else $error("Time: %0t | ERROR: Invalid cs_one_hot | actual=%0b | expected=%0b", $time, cs_one_hot, exp.cs_one_hot);
        assert(tx_data === exp.tx_data) else $error("Time: %0t | ERROR: Invalid tx_data | actual=%0p | expected=%0p", $time, tx_data, exp.tx_data);
        assert(msb_addr_err === exp.msb_addr_err) else $error("Time: %0t | ERROR: Invalid msb_addr_err | actual=%0b | expected=%0b", $time, msb_addr_err, exp.msb_addr_err);
        //$display("Time: %0t | Expected output: %0p", $time, exp);
        @(posedge clk);
        msg.msg_valid <= '0;
    endtask

    task drive_led_ctrl(input led_ctrl_t ctrl);
        @(posedge clk);
        led_ctrl <= ctrl;
    endtask

    assign led_rdata = 32'h1111_AAAA;
    assign pwm_rdata = 32'h2222_BBBB;
    assign cnt_rdata = 32'h3333_CCCC;
    assign sys_rdata = 32'h4444_DDDD;


    function logic [RGF_NUM-1:0] get_cs_one_hot(input logic [DATA_WIDTH-1:0] msb_addr);
        logic [RGF_NUM-1:0] temp_cs;
        case(msb_addr)
            LED_RGF_ADDR: temp_cs = 4'b0001;
            PWM_RGF_ADDR: temp_cs = 4'b0010;
            CNT_RGF_ADDR: temp_cs = 4'b0100;
            SYS_RGF_ADDR: temp_cs = 4'b1000;
            default: temp_cs = '0;
        endcase
        return temp_cs;
    endfunction

    function tx_mac_in_t get_tx_data(input logic [DATA_WIDTH-1:0] msb_addr, input logic [1:0][DATA_WIDTH-1:0] lsb_addr);
        logic [RGF_NUM-1:0] cs;
        tx_mac_in_t temp;
        cs = get_cs_one_hot(msb_addr);
        if (cs != '0) begin
            temp.start = 1'b1;
            temp.msg.addr = {msb_addr, lsb_addr};
            case(msb_addr)
                LED_RGF_ADDR: temp.msg.data = led_rdata;
                PWM_RGF_ADDR: temp.msg.data = pwm_rdata;
                CNT_RGF_ADDR: temp.msg.data = cnt_rdata;
                SYS_RGF_ADDR: temp.msg.data = sys_rdata;
                default: temp.msg.data = '0;
            endcase
            return temp;
        end else return '0;
    endfunction

    function logic [RGF_ADDR_WIDTH-1:0] get_led_lsb_addr(input led_ctrl_t ctrl);
        return (ctrl.select == LED16_SEL_VAL) ? LED16_VALUE_ADDR : LED17_VALUE_ADDR;
    endfunction

    function exp_t predict (input parsed_msg_t msg);
        exp_t exp_msg;
        logic [DATA_WIDTH-1:0] msb_addr;
        logic [1:0][DATA_WIDTH-1:0] lsb_addr;
        logic calc_msb_addr_err;
        if (!msg.msg_valid) begin
            exp_msg = '0;
        end 
        else begin
            msb_addr = msg.msg_data.addr[2];
            lsb_addr = msg.msg_data.addr[1:0];
            calc_msb_addr_err = (get_cs_one_hot(msb_addr) == '0);
            if (msg.msg_type == WRITE_CMD) begin
                exp_msg = '{
                    wen: 1'b1,
                    ren: 1'b0,
                    cs_one_hot: get_cs_one_hot(msb_addr),
                    addr: lsb_addr,
                    wdata: msg.msg_data.data[3:0],
                    tx_data: '0,
                    msb_addr_err: calc_msb_addr_err
                };
            end else if (msg.msg_type == READ_CMD) begin
                exp_msg = '{
                    wen: 1'b0,
                    ren: 1'b1,
                    cs_one_hot: get_cs_one_hot(msb_addr),
                    addr: lsb_addr,
                    wdata: '0,
                    tx_data: get_tx_data(msb_addr, lsb_addr),
                    msb_addr_err: calc_msb_addr_err
                };
            end else if (msg.msg_type == RGB_CMD) begin
                exp_msg = '{
                    wen: 1'b1,
                    ren: 1'b0,
                    cs_one_hot: get_cs_one_hot(LED_RGF_ADDR),
                    addr: get_led_lsb_addr(led_ctrl),
                    wdata: msg.msg_data.data[3:0],
                    tx_data: '0,
                    msb_addr_err: '0
                };
            end else if (msg.msg_type == LED_CMD) begin
                exp_msg = '{
                    wen: 1'b1,
                    ren: 1'b0,
                    cs_one_hot: get_cs_one_hot(LED_RGF_ADDR),
                    addr: LED_CTRL_ADDR,
                    wdata: {(led_ctrl >> 2), (msg.msg_data.data == '0) ? LED16_SEL_VAL : LED17_SEL_VAL},
                    tx_data: '0,
                    msb_addr_err: '0
                };
            end else exp_msg = '0;
        end
        return exp_msg;
    endfunction


    initial begin
        reset_dut();
        drive_msg('{msg_valid: 1'b0, msg_type: WRITE_CMD, msg_data: '1});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type:WRITE_CMD, msg_data: '{addr: 24'h000008, data: 48'h0000AABBCC}});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type: READ_CMD, msg_data: '{addr: 24'h010000, data: '0}});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type: RGB_CMD, msg_data: '{addr: '0, data: 48'h000000102030}});

        repeat(2) @(posedge clk);

        drive_led_ctrl('{led17_cie: 1'b0, led16_cie: 1'b0, led17_power: 1'b1, led16_power: 1'b1, select: LED17_SEL_VAL});
        drive_msg('{msg_valid: 1'b1, msg_type: RGB_CMD, msg_data: '{addr: '0, data: 48'h000000405060}});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type: LED_CMD, msg_data: '{addr: '0, data: 48'h000000000000}});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type: LED_CMD, msg_data: '{addr: '0, data: 48'h000000000001}});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type: WRITE_CMD, msg_data: '{addr: 24'h050000, data: 48'h0000DEADBEEF}});

        repeat(2) @(posedge clk);

        drive_msg('{msg_valid: 1'b1, msg_type: READ_CMD, msg_data: '{addr: 24'h050000, data: '0}});

        repeat(2) @(posedge clk);

        $finish;
    end


endmodule
