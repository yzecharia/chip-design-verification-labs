package pwm_rgf_pkg;
    import lab7_pkg::*;

    // PWM RGF
    // sweep_time = window size: number of slots in one PWM period (the resolution)
    // time_slots = slot length: number of clock cycles per slot
    typedef struct packed {
        logic [15:0] sweep_time;    // [31:16]
        logic [15:0] time_slots;    // [15:0]
    } pwm_cfg_t;

    localparam TIME_SLOTS_WIDTH = 16;

    typedef logic [2:0][TIME_SLOTS_WIDTH-1:0] scaled_val_t;

    // one colour control register, used by red_pwm_ctrl, green_pwm_ctrl, blue_pwm_ctrl
    typedef struct packed {
        logic [12:0] freq;          // [23:11]
        logic [1:0] mag;            // [10:9]
        logic [8:0] phase;          // [8:0]
    } pwm_ctrl_t;

    localparam RAINBOW_RED_PHASE = 9'b0;
    localparam RAINBOW_GREEN_PHASE = 9'h0AB;
    localparam RAINBOW_BLUE_PHASE = 9'h155;

    typedef struct packed {
        logic addr_err;             // [0]
    } pwm_status_t;

    typedef struct packed {
        pwm_cfg_t pwm_cfg;
        pwm_ctrl_t red_ctrl, green_ctrl, blue_ctrl;
    } pwm_rgf_msg_t;

    localparam logic [RGF_ADDR_WIDTH-1:0] PWM_CFG_ADDR = RGF_ADDR_WIDTH'(0);
    localparam logic [RGF_ADDR_WIDTH-1:0] RED_PWM_CTRL_ADDR = RGF_ADDR_WIDTH'(4);
    localparam logic [RGF_ADDR_WIDTH-1:0] GREEN_PWM_CTRL_ADDR = RGF_ADDR_WIDTH'(8);
    localparam logic [RGF_ADDR_WIDTH-1:0] BLUE_PWM_CTRL_ADDR = RGF_ADDR_WIDTH'(12);
    localparam logic [RGF_ADDR_WIDTH-1:0] PWM_STATUS_ADDR = RGF_ADDR_WIDTH'(16);

    localparam int SWEEP_TIME_STOP_BIT = 31;
    localparam int SWEEP_TIME_START_BIT = 16;
    localparam int TIME_SLOTS_STOP_BIT = 15;
    localparam int TIME_SLOTS_START_BIT = 0;
    localparam int PWM_CFG_STOP_BIT = 31;
    localparam int PWM_CFG_START_BIT = 0;

    // the three colour registers have the same layout, so the field bits are shared
    localparam int PWM_CTRL_FREQ_STOP_BIT = 23;
    localparam int PWM_CTRL_FREQ_START_BIT = 11;
    localparam int PWM_CTRL_MAG_STOP_BIT = 10;
    localparam int PWM_CTRL_MAG_START_BIT = 9;
    localparam int PWM_CTRL_PHASE_STOP_BIT = 8;
    localparam int PWM_CTRL_PHASE_START_BIT = 0;

    localparam int RED_PWM_CTRL_STOP_BIT = 23;
    localparam int RED_PWM_CTRL_START_BIT = 0;

    localparam int GREEN_PWM_CTRL_STOP_BIT = 23;
    localparam int GREEN_PWM_CTRL_START_BIT = 0;

    localparam int BLUE_PWM_CTRL_STOP_BIT = 23;
    localparam int BLUE_PWM_CTRL_START_BIT = 0;

    localparam int PWM_STATUS_STOP_BIT = 0;
    localparam int PWM_STATUS_START_BIT = 0;

    // legal range of the freq field, from the lab PDF (min val 10, max val 5000)
    localparam logic [12:0] PWM_FREQ_MIN = 13'd10;
    localparam logic [12:0] PWM_FREQ_MAX = 13'd5000;

    // reset values, written field by field: {sweep_time, time_slots} and {unused, freq, mag, phase}
    localparam logic [RGF_DATA_WIDTH-1:0] PWM_CFG_RESET_VAL = {16'd1024, 16'd1};
    localparam logic [RGF_DATA_WIDTH-1:0] RED_PWM_CTRL_RESET_VAL = {8'd0, 13'd10, 2'd0, 9'd0};
    localparam logic [RGF_DATA_WIDTH-1:0] GREEN_PWM_CTRL_RESET_VAL = {8'd0, 13'd10, 2'd0, 9'd0};
    localparam logic [RGF_DATA_WIDTH-1:0] BLUE_PWM_CTRL_RESET_VAL = {8'd0, 13'd10, 2'd0, 9'd0};
    localparam logic [RGF_DATA_WIDTH-1:0] PWM_STATUS_RESET_VAL = '0;

    localparam CH_NUM = 3;


endpackage
