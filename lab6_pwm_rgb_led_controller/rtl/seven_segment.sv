import lab6_pkg::*;

module seven_segment (
    input logic [DIG_IN_WIDTH-1:0] data_val,
    output logic [SS_DIG_WIDTH-1:0] ss_dig
);

    always_comb begin
        unique case (data_val)
            4'h0: ss_dig = 7'b0000001;
            4'h1: ss_dig = 7'b1001111;
            4'h2: ss_dig = 7'b0010010;
            4'h3: ss_dig = 7'b0000110;
            4'h4: ss_dig = 7'b1001100;
            4'h5: ss_dig = 7'b0100100;
            4'h6: ss_dig = 7'b0100000;
            4'h7: ss_dig = 7'b0001111;
            4'h8: ss_dig = 7'b0000000;
            4'h9: ss_dig = 7'b0000100;
            4'hA: ss_dig = 7'b0001000;
            4'hB: ss_dig = 7'b1100000;
            4'hC: ss_dig = 7'b0110001;
            4'hD: ss_dig = 7'b1000010;
            4'hE: ss_dig = 7'b0110000;
            4'hF: ss_dig = 7'b0111000;
            default: ss_dig = 7'b1111111;
        endcase
    end
endmodule
