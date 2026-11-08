import lab6_pkg::*;
`include "lab6_definitions.svh"

module tb_rx_mac;

    bit clk = '0;
    always #5 clk = !clk;

    logic reset_n = '0;
    logic done = '0;
    logic [DATA_WIDTH-1:0] data_in = '0;
    packet_cfg_t pkt_data;
    logic pkt_valid;

    rx_mac dut (
        .clk(clk),
        .reset_n(reset_n),
        .done(done),
        .data_in(data_in),
        .pkt_data(pkt_data),
        .pkt_valid(pkt_valid)
    );

    task reset_dut();
        $display("Time: %0t | TASK: Reset DUT", $time);
        reset_n = '0; #(CLK_PERIOD);
        assert(!pkt_valid);
        assert(pkt_data === '0);
        reset_n = '1;
    endtask    

    // full flow : {RXXX,GXXX,BXXX}
    task drive_full_input(input logic [DIGITS-1:0][DATA_WIDTH-1:0] row_val, col_val, val);
        for (int i = 0; i < 16; i++) begin
            case(i)
                0: data_in = MSG_START_VAL;
                1: data_in = R_VAL;
                2: data_in = row_val[2];
                3: data_in = row_val[1];
                4: data_in = row_val[0];
                5, 10: data_in = COMMA_VAL;
                6: data_in = G_VAL;
                7: data_in = col_val[2];
                8: data_in = col_val[1];
                9: data_in = col_val[0];
                11: data_in = B_VAL;
                12: data_in = val[2];
                13: data_in = val[1];
                14: data_in = val[0];
                15: data_in = MSG_CLOSE_VAL;
                default: data_in = MSG_START_VAL;
            endcase
            done = '1; #(CLK_PERIOD);
            if (i == 15) begin
                assert(pkt_valid === '1);
                //$display("Time: %0t | %h", $time, build_valid_pkt(row_val, col_val, val));
                assert(pkt_data === build_exp_pkt(row_val, col_val, val));
            end
            done = '0; #(CLK_PERIOD);
        end
    endtask

    task drive_full_input_bad(input logic [DIGITS-1:0][DATA_WIDTH-1:0] row_val, col_val, val);
        for (int i = 0; i < 17; i++) begin
            case(i)
                0: data_in = MSG_START_VAL;
                1: data_in = R_VAL;
                2: data_in = row_val[2];
                3: data_in = row_val[1];
                4: data_in = row_val[0];
                5, 10: data_in = COMMA_VAL;
                6: data_in = G_VAL;
                7: data_in = col_val[2];
                8: data_in = col_val[1];
                9: data_in = col_val[0];
                11: data_in = B_VAL;
                12: data_in = val[2];
                13: data_in = val[1];
                14: data_in = val[0];
                15: data_in = MSG_START_VAL;
                16: data_in = MSG_CLOSE_VAL;
                default: data_in = MSG_START_VAL;
            endcase
            done = '1; #(CLK_PERIOD);
            if (i == 15) begin
                assert(pkt_valid === '0);
                //$display("Time: %0t | %h", $time, build_exp_pkt(row_val, col_val, val));
                assert(pkt_data !== build_exp_pkt(row_val, col_val, val));
            end
            done = '0; #(CLK_PERIOD);
        end
    endtask

    task drive_restart_input(input logic [DIGITS-1:0][DATA_WIDTH-1:0] row_val, col_val, val);
        for (int i = 0; i < 20; i++) begin
            case(i)
                0, 4: data_in = MSG_START_VAL;
                1, 5: data_in = R_VAL;
                2, 6: data_in = row_val[2];
                3, 7: data_in = row_val[1];
                8: data_in = row_val[0];
                9, 14: data_in = COMMA_VAL;
                10: data_in = G_VAL;
                11: data_in = col_val[2];
                12: data_in = col_val[1];
                13: data_in = col_val[0];
                15: data_in = B_VAL;
                16: data_in = val[2];
                17: data_in = val[1];
                18: data_in = val[0];
                19: data_in = MSG_CLOSE_VAL;
                default: data_in = MSG_START_VAL;
            endcase
            done = '1; #(CLK_PERIOD);
            if (i == 19) begin
                assert(pkt_valid === '1);
                assert(pkt_data === build_exp_pkt(row_val, col_val, val));
            end
            done = '0; #(CLK_PERIOD);
        end
    endtask

    task drive_one_group_input(input logic [DIGITS-1:0][DATA_WIDTH-1:0] row_val);
        for (int i = 0; i < 6; i++) begin
            case(i)
                0: data_in = MSG_START_VAL;
                1: data_in = R_VAL;
                2: data_in = row_val[2];
                3: data_in = row_val[1];
                4: data_in = row_val[0];
                5: data_in = MSG_CLOSE_VAL;
                default: data_in = MSG_START_VAL;
            endcase
            done = '1; #(CLK_PERIOD);
            if (i == 5) begin
                assert(pkt_valid === '1);
                assert(pkt_data === {{10*DATA_WIDTH{1'b0}}, MSG_START_VAL, R_VAL, row_val, MSG_CLOSE_VAL});
            end
            done = '0; #(CLK_PERIOD);
        end
    endtask

    task drive_four_groups_input(input logic [DIGITS-1:0][DATA_WIDTH-1:0] row_val, col_val, val);
        for (int i = 0; i < 21; i++) begin
            case(i)
                0: data_in = MSG_START_VAL;
                1, 16: data_in = R_VAL;
                2, 17: data_in = row_val[2];
                3, 18: data_in = row_val[1];
                4, 19: data_in = row_val[0];
                5, 10, 15: data_in = COMMA_VAL;
                6: data_in = G_VAL;
                7: data_in = col_val[2];
                8: data_in = col_val[1];
                9: data_in = col_val[0];
                11: data_in = B_VAL;
                12: data_in = val[2];
                13: data_in = val[1];
                14: data_in = val[0];
                20: data_in = MSG_CLOSE_VAL;
                default: data_in = MSG_START_VAL;
            endcase
            done = '1; #(CLK_PERIOD);
            if (i >= 15) begin
                assert(pkt_valid === '0);
            end
            done = '0; #(CLK_PERIOD);
        end
    endtask

    function packet_cfg_t build_exp_pkt(input logic [DIGITS-1:0][DATA_WIDTH-1:0] row_val, col_val, val);
        packet_cfg_t p;
        p.msg_start = MSG_START_VAL;
        p.op_2      = R_VAL;
        p.value_2   = row_val;
        p.comma0    = COMMA_VAL;
        p.op_1      = G_VAL;
        p.value_1   = col_val;
        p.comma1    = COMMA_VAL;
        p.op_0      = B_VAL;
        p.value_0   = val;
        p.msg_close = MSG_CLOSE_VAL;
        return p;
    endfunction

    initial begin
        reset_dut();

        drive_full_input(32'h313233, 32'h343536, 32'h373839);

        #(CLK_PERIOD * 5);

        drive_full_input_bad(32'h090807, 32'h060504, 32'h030201);
        #(CLK_PERIOD * 5);

        drive_restart_input(32'h323535, 32'h303030, 32'h313238);
        #(CLK_PERIOD * 5);

        drive_one_group_input(32'h313233);
        #(CLK_PERIOD * 5);

        drive_four_groups_input(32'h313233, 32'h343536, 32'h373839);
        #(CLK_PERIOD * 5);

        $finish;
    end

endmodule
