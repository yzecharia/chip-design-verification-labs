import lab7_pkg::*;
import sys_rgf_pkg::*;
module sys_rgf (
    input logic clk, reset_n,
    input logic cs, wen, ren,
    input logic [RGF_ADDR_WIDTH-1:0] addr,
    input logic [RGF_DATA_WIDTH-1:0] wdata,
    input logic msb_addr_err, // from reg_interconnect, high for one clock
    output logic [RGF_DATA_WIDTH-1:0] rdata,
    output logic sw_rst, // high for one clock after 1 is written to sys_ctrl.reset
    output logic en
);

    sys_status_t sys_status;

    logic ctrl_sel, status_sel;
    logic addr_err_comb;

    always_comb begin : reg_addr_dec
        ctrl_sel = '0;
        status_sel = '0;
        addr_err_comb = '0;
        unique case(addr)
            SYS_CTRL_ADDR: ctrl_sel = '1;
            SYS_STATUS_ADDR: status_sel = '1;
            default: addr_err_comb = '1;
        endcase
    end

    // write to sys_ctrl
    logic ctrl_wr;
    assign ctrl_wr = cs && wen && ctrl_sel;

    // sys_ctrl.en (RW) - keeps its value until the next write
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) en <= SYS_CTRL_RESET_VAL[SYS_EN_STOP_BIT:SYS_EN_START_BIT];
        else if (ctrl_wr) en <= wdata[SYS_EN_STOP_BIT:SYS_EN_START_BIT];
    end

    // sys_ctrl.reset (WO) - not stored, writing 1 gives a one clock pulse
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) sw_rst <= '0;
        else if (ctrl_wr && wdata[SYS_RESET_STOP_BIT:SYS_RESET_START_BIT]) sw_rst <= '1;
        else sw_rst <= '0;
    end

    // sys_status (R0C) - each flag has its own set condition, both are cleared when sys_status is read
    logic addr_err;
    assign addr_err = cs && (wen || ren) && addr_err_comb;
    logic clr_status;
    assign clr_status = cs && ren && status_sel;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) sys_status <= SYS_STATUS_RESET_VAL[SYS_STATUS_STOP_BIT:SYS_STATUS_START_BIT];
        else begin
            if (addr_err) sys_status.addr_err <= 1'b1;
            else if (clr_status) sys_status.addr_err <= '0;

            if (msb_addr_err) sys_status.msb_addr_err <= 1'b1;
            else if (clr_status) sys_status.msb_addr_err <= '0;
        end
    end

    // read mux - sys_ctrl.reset always reads 0, so only en is returned
    always_comb begin
        rdata = '0;
        if (cs & ren) begin
            unique case(1'b1)
                ctrl_sel: rdata = en;
                status_sel: rdata = sys_status;
                default: rdata = '0;
            endcase
        end
    end

endmodule