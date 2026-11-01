import lab5_pkg::*;

module debounce #(
    parameter DEB_COUNT = 2000000
) (
    input logic clk, reset_n, io_in,
    output logic io_d
);

    localparam COUNT_WIDTH = DEB_COUNT > 1 ? $clog2(DEB_COUNT) : 1;
    localparam [COUNT_WIDTH-1:0] ONE = 1;

    logic [COUNT_WIDTH-1:0] cnt;

    logic io_meta, io_sync;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) {io_sync, io_meta} <= '0;
        else {io_sync, io_meta} <= {io_meta, io_in};
    end


    deb_state_t state, next;
    logic cnt_max; assign cnt_max = (cnt == DEB_COUNT-1);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) cnt <= '0;
        else if (state != next) cnt <= '0;
        else if ((state == DEB_W0) || (state == DEB_W1)) cnt <= cnt + ONE;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= DEB_S0;
        else state <= next;
    end

    always_comb begin
        next = state;
        unique case(state)
            DEB_S0: next = (io_sync) ? DEB_W1 : DEB_S0;
            DEB_W1: next = (!io_sync) ? DEB_S0 : ((cnt_max) ? DEB_S1 : DEB_W1);
            DEB_S1: next = (!io_sync) ? DEB_W0 : DEB_S1;
            DEB_W0: next = (io_sync) ? DEB_S1 : ((cnt_max) ? DEB_S0 : DEB_W0);
            default: next = state; 
        endcase
    end

    assign io_d = (state == DEB_S1) || (state == DEB_W0);

endmodule
