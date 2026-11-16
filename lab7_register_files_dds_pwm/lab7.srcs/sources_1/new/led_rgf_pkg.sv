package led_rgf_pkg;
    import lab7_pkg::*;

    // LED RGF
    typedef struct packed {
        logic led17_cie;
        logic led16_cie;
        logic led17_power;
        logic led16_power;
        logic [1:0] select;
    } led_ctrl_t;

    typedef logic [1:0] led_pattern_t;

    typedef struct packed {
        logic [SCREENS_PER_VALUE-1:0][NIBBLE_WIDTH-1:0] red;
        logic [SCREENS_PER_VALUE-1:0][NIBBLE_WIDTH-1:0] green;
        logic [SCREENS_PER_VALUE-1:0][NIBBLE_WIDTH-1:0] blue;
    } led_value_t;

    typedef struct packed {
        logic addr_err;
    } led_status_t;

    typedef struct packed {
        logic btnc;
        logic display_led;
        led_value_t led_value;
    } selector_data_t;

    typedef struct packed {
        led_ctrl_t led_ctrl;
        led_pattern_t led_pattern;
        led_value_t led16_value, led17_value;
    } led_rgf_msg_t;

    localparam [RGF_ADDR_WIDTH-1:0] LED_CTRL_ADDR = RGF_ADDR_WIDTH'(0);
    localparam [RGF_ADDR_WIDTH-1:0] LED_PATTERN_ADDR = RGF_ADDR_WIDTH'(4);
    localparam [RGF_ADDR_WIDTH-1:0] LED16_VALUE_ADDR = RGF_ADDR_WIDTH'(8);
    localparam [RGF_ADDR_WIDTH-1:0] LED17_VALUE_ADDR = RGF_ADDR_WIDTH'(12);
    localparam [RGF_ADDR_WIDTH-1:0] LED_STATUS_ADDR = RGF_ADDR_WIDTH'(16);

    localparam LED17_CIE_START_BIT = 5;
    localparam LED17_CIE_STOP_BIT = 5;
    localparam LED16_CIE_START_BIT = 4;
    localparam LED16_CIE_STOP_BIT = 4;
    localparam LED17_POWER_START_BIT = 3;
    localparam LED17_POWER_STOP_BIT = 3;
    localparam LED16_POWER_START_BIT = 2;
    localparam LED16_POWER_STOP_BIT = 2;
    localparam SELECT_STOP_BIT = 1;
    localparam SELECT_START_BIT = 0;
    localparam LED_CTRL_STOP_BIT = 5;
    localparam LED_CTRL_START_BIT = 0;

    localparam LED_PATTERN_STOP_BIT = 1;
    localparam LED_PATTERN_START_BIT = 0;

    localparam LED16_VALUE_RED_STOP_BIT = 23;
    localparam LED16_VALUE_RED_START_BIT = 16;
    localparam LED16_VALUE_GREEN_STOP_BIT = 15;
    localparam LED16_VALUE_GREEN_START_BIT = 8;
    localparam LED16_VALUE_BLUE_STOP_BIT = 7;
    localparam LED16_VALUE_BLUE_START_BIT = 0;
    localparam LED16_VALUE_STOP_BIT = 23;
    localparam LED16_VALUE_START_BIT = 0;

    localparam LED17_VALUE_RED_STOP_BIT = 23;
    localparam LED17_VALUE_RED_START_BIT = 16;
    localparam LED17_VALUE_GREEN_STOP_BIT = 15;
    localparam LED17_VALUE_GREEN_START_BIT = 8;
    localparam LED17_VALUE_BLUE_STOP_BIT = 7;
    localparam LED17_VALUE_BLUE_START_BIT = 0;
    localparam LED17_VALUE_STOP_BIT = 23;
    localparam LED17_VALUE_START_BIT = 0;

    localparam LED_STATUS_STOP_BIT = 0;
    localparam LED_STATUS_START_BIT = 0;

    localparam LED_CTRL_RESET_VAL = RGF_DATA_WIDTH'(1);
    localparam LED_PATTERN_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam LED16_VALUE_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam LED17_VALUE_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam LED_STATUS_RESET_VAL = RGF_DATA_WIDTH'(0);

    localparam LED16_SEL_VAL = 2'b01;
    localparam LED17_SEL_VAL = 2'b10;

    typedef enum logic [1:0] { STATIC, BREATH, RAINBOW, INVALID } pattern_cfg_t;

endpackage
