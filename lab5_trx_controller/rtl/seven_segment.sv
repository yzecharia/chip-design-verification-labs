import lab5_pkg::*;

module seven_segment (
    input seven_segment_data_t ss_in,
    output display_ctrl_data_t display_ctrl_data
);

    always_comb begin
        display_ctrl_data.dp = ss_in.dp;
        if (ss_in.dash) display_ctrl_data.ss_dig = DASH_VAL;
        else unique case (ss_in.data_val)
            4'h0: display_ctrl_data.ss_dig = 7'b0000001;
            4'h1: display_ctrl_data.ss_dig = 7'b1001111;
            4'h2: display_ctrl_data.ss_dig = 7'b0010010;
            4'h3: display_ctrl_data.ss_dig = 7'b0000110;
            4'h4: display_ctrl_data.ss_dig = 7'b1001100;
            4'h5: display_ctrl_data.ss_dig = 7'b0100100;
            4'h6: display_ctrl_data.ss_dig = 7'b0100000;
            4'h7: display_ctrl_data.ss_dig = 7'b0001111;
            4'h8: display_ctrl_data.ss_dig = 7'b0000000;
            4'h9: display_ctrl_data.ss_dig = 7'b0000100;
            4'hA: display_ctrl_data.ss_dig = 7'b0001000;
            4'hB: display_ctrl_data.ss_dig = 7'b1100000;
            4'hC: display_ctrl_data.ss_dig = 7'b0110001;
            4'hD: display_ctrl_data.ss_dig = 7'b1000010;
            4'hE: display_ctrl_data.ss_dig = 7'b0110000;
            4'hF: display_ctrl_data.ss_dig = 7'b0111000;
            default: display_ctrl_data.ss_dig = 7'b1111111;
        endcase
    end
endmodule
