import lab6_pkg::*;
`include "lab6_definitions.svh"

module debounce_cluster
#(
    parameter DEB_COUNT = `DEB_COUNT
) (
    input logic clk, cpu_reset,
    input btn_ctf_t io_in,
    output btn_ctf_t io_d,
    output logic cpu_reset_d = '0
);

    localparam DEB_COUNT_WIDTH = $clog2(DEB_COUNT);
    localparam [DEB_COUNT_WIDTH-1:0] ONE = 1;
    localparam IO_WIDTH = BUTTON_NUM;

    // Reset Debounce
    // Initial value for reset regs are 0, so that dut has power on reset
    logic reset_sync = '0;
    logic reset_meta = '0;
    always_ff @(posedge clk) begin
        {reset_sync, reset_meta} <= {reset_meta, cpu_reset};
    end

    logic reset_prev = '0;
    always_ff @(posedge clk) begin
        reset_prev <= reset_sync;
    end
    logic reset_edge;
    assign reset_edge = reset_prev ^ reset_sync;

    logic [DEB_COUNT_WIDTH-1:0] reset_cnt = '0;
    logic reset_stable;
    assign reset_stable = (reset_cnt == DEB_COUNT - 1);
    always_ff @(posedge clk) begin
        if (reset_edge) reset_cnt <= '0;
        else if (!reset_stable) reset_cnt <= reset_cnt + ONE;
    end

    always_ff @(posedge clk) begin
        if (reset_stable & !reset_edge) cpu_reset_d <= reset_sync;
    end


    //BTNC Debounce

    genvar i;
    generate
        for(i = 0; i < IO_WIDTH; i++) begin : io_deb
            debounce #(.DEB_COUNT(DEB_COUNT)) debounce_i (clk, cpu_reset_d, io_in[i], io_d[i]);
        end
    endgenerate

    
endmodule
