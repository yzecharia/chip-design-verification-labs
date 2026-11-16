import lab7_pkg::*;
import pwm_rgf_pkg::*;
import led_rgf_pkg::*;
// SLOTS is passed down by name from chip_top (1024 default, 512 .. 8192);
module pwm (
    input logic clk, reset_n,
    input pwm_cfg_t pwm_cfg,
    input [TIME_SLOTS_WIDTH-1:0] scaled_val,
    output logic pwm_signal, 
    output logic wrap_cnt
);

    /*
        pwm_cfg holds:
            - sweep_time - Numeber of slots
            - time_slots - Number of clk cycles per slot
            with this we have 2 values for our counters
            First counter counts to time_slots and sends a en signal to second counter that counts to sweep_time
            and second counter has the (cnt < value) signal as wee
    */

    // time_slots counter
    localparam PWM_WIDTH = 16;
    logic [PWM_WIDTH-1:0] time_slots_cnt;
    logic sweep_time_cnt_en; assign sweep_time_cnt_en = (time_slots_cnt >= pwm_cfg.time_slots - 1);
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) time_slots_cnt <= '0;
        else if (sweep_time_cnt_en) time_slots_cnt <= '0;
        else time_slots_cnt <= time_slots_cnt + 1;
    end

    // sweep_time counter
    logic [PWM_WIDTH-1:0] sweep_time_cnt;
    logic sweep_time_last; assign sweep_time_last = (sweep_time_cnt >= pwm_cfg.sweep_time - 1);
    logic sweep_time_wrap; assign sweep_time_wrap = sweep_time_last && sweep_time_cnt_en;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) sweep_time_cnt <= '0;
        else if (sweep_time_wrap) sweep_time_cnt <= '0;
        else if (sweep_time_cnt_en) sweep_time_cnt <= sweep_time_cnt + 1;
    end

    logic [TIME_SLOTS_WIDTH-1:0] val_reg;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) val_reg <= '0;
        else if (sweep_time_wrap) val_reg <= scaled_val;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) pwm_signal <= '0;
        else pwm_signal <= (sweep_time_cnt < val_reg);
    end

    assign wrap_cnt = sweep_time_wrap;

endmodule
