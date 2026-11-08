import lab6_pkg::*;

module selector (
    input logic clk, reset_n,
    input btn_ctf_t btn_in,
    input pixel_parsed_t parsed_pixel_value,
    input logic parsed_led_value,
    input logic pixel_valid, led_valid,
    output pixel_parsed_t display_pixel,
    output pixel_parsed_t pwm_pixel,
    output logic pwm_new_data,
    output logic pwm_led,
    output logic display_led,
    output leds_cfg_t leds_out
);
    // 1. need to convert btn_in levels to edge pulses
    btn_ctf_t btn_edge, btn_prev;
    genvar i;
    generate
        for (i = 0; i < 5; i++) begin : BTN_EDGE_DETECTORS
            always_ff @(posedge clk) begin
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

    always_ff @(posedge clk) begin
        if (!reset_n) display_cnt <= '0;
        else if (btn_edge.right & !is_t0) display_cnt <= display_cnt - 1;
        else if (btn_edge.left & !is_t3) display_cnt <= display_cnt + 1; 
    end

    // Pixel value
    logic [2:0] is_max, is_min;
    generate
        for (i = 0; i < 3; i++) begin : MIN_MAX
            assign is_max[i] = (display_pixel[DATA_WIDTH*i +: DATA_WIDTH] == MAX_PIXEL_VAL);
            assign is_min[i] = (display_pixel[DATA_WIDTH*i +: DATA_WIDTH] == MIN_PIXEL_VAL);
        end
    endgenerate

    generate
        for (i = 0; i < 3; i++) begin : UP_DOWN_VAL
            always_ff @(posedge clk) begin
                if (!reset_n) display_pixel[DATA_WIDTH*i +: DATA_WIDTH] <= '0;
                else if (pixel_valid) display_pixel[DATA_WIDTH*i +: DATA_WIDTH] <= parsed_pixel_value[DATA_WIDTH*i +: DATA_WIDTH];
                else if (!is_max[i] & btn_edge.up & (display_cnt == i)) display_pixel[DATA_WIDTH*i +: DATA_WIDTH] <= display_pixel[DATA_WIDTH*i +: DATA_WIDTH] + 1;
                else if (!is_min[i] & btn_edge.down & (display_cnt == i)) display_pixel[DATA_WIDTH*i +: DATA_WIDTH] <= display_pixel[DATA_WIDTH*i +: DATA_WIDTH] - 1;
            end
        end
    endgenerate


    always_ff @(posedge clk) begin
        if (!reset_n) {pwm_pixel, pwm_new_data} <= '0;
        else if (pixel_valid) {pwm_pixel, pwm_new_data} <= {parsed_pixel_value, 1'b1};
        else if (btn_edge.center) {pwm_pixel, pwm_new_data} <= {display_pixel, 1'b1};
        else pwm_new_data <= '0;
    end

    // led value
    always_ff @(posedge clk) begin
        if (!reset_n) display_led <= '0;
        else if (led_valid) display_led <= parsed_led_value;
        else if (((btn_edge.down & display_led) | (btn_edge.up & !display_led)) & (display_cnt == 2'd3)) display_led <= !display_led;
    end
    
    always_ff @(posedge clk) begin
        if (!reset_n) pwm_led <= '0;
        else if (led_valid) pwm_led <= parsed_led_value;
        else if (btn_edge.center) pwm_led <= display_led; 
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

endmodule
