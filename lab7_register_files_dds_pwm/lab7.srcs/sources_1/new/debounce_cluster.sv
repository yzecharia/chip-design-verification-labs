import lab7_pkg::*;
`include "lab7_definitions.svh"

module debounce_cluster
#(
    parameter DEB_COUNT = `DEB_COUNT
) (
    input logic clk, cpu_reset,
    input btn_ctf_t io_in,
    output btn_ctf_t io_d,
    output logic cpu_reset_d = '0
);

    localparam IO_WIDTH = BUTTON_NUM;

    // Initial value for reset regs are 0, so that dut has power on reset
    logic reset_meta = '0;
    always_ff @(posedge clk or negedge cpu_reset) begin
        if (!cpu_reset) {cpu_reset_d, reset_meta} <= '0;
        else {cpu_reset_d, reset_meta} <= {reset_meta, 1'b1};
    end


    //BTNC Debounce

    genvar i;
    generate
        for(i = 0; i < IO_WIDTH; i++) begin : io_deb
            debounce #(.DEB_COUNT(DEB_COUNT)) debounce_i (clk, cpu_reset_d, io_in[i], io_d[i]);
        end
    endgenerate

    
endmodule
