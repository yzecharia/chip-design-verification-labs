import lab7_pkg::*;
import led_rgf_pkg::*;
module selector (
    input logic clk, reset_n,
    input btn_ctf_t btn_in,
    input led_rgf_msg_t led_rgf_msg,
    input logic pc_led_update,
    output leds_cfg_t leds_out,
    output selector_data_t sel_out
);

    /*
        New Selector need to work with led_rgf

        1. New inputs: only btn_in and led_rgf_msg
        2. New outputs:  leds_out,  sel_out(includs display_led and led_value)

        Operation:
        if (btn_in.btnc) is pressed then values, all get loaded led_rgf and display_values
        else display_values follow led_rgf

        What i need from the led_rgf_msg msg
        led_ctrl.select to select what to display on T3
        led16_value, led17_value for T0-T2

        both get updated on btnc (so write back to led_rgf)

        sending back to led_rgf:
        logic [1:0] select
        logic [24:0] led_value
    */

    // 1. need to convert btn_in levels to edge pulses
    btn_ctf_t btn_edge, btn_prev;
    genvar i;
    generate
        for (i = 0; i < 5; i++) begin : BTN_EDGE_DETECTORS
            always_ff @(posedge clk or negedge reset_n) begin
                if (!reset_n) btn_prev[i] <= '0;
                else btn_prev[i] <= btn_in[i]; 
            end
            assign btn_edge[i] = !btn_prev[i] & btn_in[i];
        end
    endgenerate

    localparam DISPLAY_SECTIONS = 4;
    typedef enum logic [DISPLAY_SECTIONS-1:0] { 
        FIRST_T = 4'b0001,
        LAST_T = 4'b1000
    } t_e;

    localparam MAX_PIXEL_VAL = 255;
    localparam MIN_PIXEL_VAL = 0;

    logic [1:0] display_cnt;
    logic is_t0; assign is_t0 = (display_cnt == 2'b00);
    logic is_t3; assign is_t3 = (display_cnt == 2'b11);

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) display_cnt <= '0;
        else if (btn_edge.right & !is_t0) display_cnt <= display_cnt - 1;
        else if (btn_edge.left & !is_t3) display_cnt <= display_cnt + 1; 
    end

    // Pixel value
    logic [2:0][DATA_WIDTH-1:0] pixel;
    logic [2:0] is_max, is_min;
    generate
        for (i = 0; i < 3; i++) begin : MIN_MAX
            assign is_max[i] = (pixel[i] == MAX_PIXEL_VAL);
            assign is_min[i] = (pixel[i] == MIN_PIXEL_VAL);
        end
    endgenerate

    logic [2:0][DATA_WIDTH-1:0] led_val; assign led_val = (led_rgf_msg.led_ctrl.select == LED16_SEL_VAL) ? led_rgf_msg.led16_value : led_rgf_msg.led17_value;
    generate
        for (i = 0; i < 3; i++) begin : UP_DOWN_VAL
            always_ff @(posedge clk or negedge reset_n) begin
                if (!reset_n) pixel[i] <= '0;
                else if (pc_led_update & !btn_edge.center) pixel[i] <= led_val[i]; // need to change to value from led_rgf_msg
                else if (!is_max[i] & btn_edge.up & (display_cnt == i)) pixel[i] <= pixel[i] + 1;
                else if (!is_min[i] & btn_edge.down & (display_cnt == i)) pixel[i] <= pixel[i] - 1;
            end
        end
    endgenerate

    // led value
    logic led_sel_val; assign led_sel_val = (led_rgf_msg.led_ctrl.select == LED16_SEL_VAL) ? 1'b0 : 1'b1;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) sel_out.display_led <= '0;
        else if (pc_led_update & !btn_edge.center) sel_out.display_led <= led_sel_val; //need to change to value from led_rgf
        else if (((btn_edge.down & sel_out.display_led) | (btn_edge.up & !sel_out.display_led)) & (display_cnt == 2'd3)) sel_out.display_led <= !sel_out.display_led;
    end
    
    always_comb begin
        unique case(display_cnt) 
            2'd0: leds_out = 16'h0030;
            2'd1: leds_out = 16'h0180;
            2'd2: leds_out = 16'h0600;
            2'd3: leds_out = 16'h3000;
            default: leds_out = '0;
        endcase
    end

    assign sel_out.led_value = pixel;
    assign sel_out.btnc = btn_edge.center;

endmodule
