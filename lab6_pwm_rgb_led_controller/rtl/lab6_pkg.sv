package lab6_pkg;

    // Global
    // Clock frequency
    localparam CLK_FREQ = 100000000;
    localparam DATA_WIDTH = 8;
    localparam DIG_IN_WIDTH = 4;
    localparam NUM_DIGITS = 4;
    localparam BUTTON_NUM = 5;

    localparam PACKET_SIZE = 16;

    // TB Values
    localparam CLK_PERIOD = 10;

    typedef struct packed {
        logic up, down, left, right, center;
    } btn_ctf_t;

    // UART frame (tx_phy)
    localparam START_BIT_SIZE = 1;
    localparam STOP_BIT_SIZE = 1;
    localparam FRAME_WIDTH = START_BIT_SIZE + DATA_WIDTH + STOP_BIT_SIZE;

    // RX message (rx_mac -> parser)
    localparam DIGITS = 3;
    localparam MAX_GROUPS = 3;
    localparam NUM_OF_VALUES = 3;
    typedef struct packed {
        logic [DATA_WIDTH-1:0] msg_start;
        logic [DATA_WIDTH-1:0] op_2;
        logic [DIGITS-1:0][DATA_WIDTH-1:0] value_2;
        logic [DATA_WIDTH-1:0] comma0;
        logic [DATA_WIDTH-1:0] op_1;
        logic [DIGITS-1:0][DATA_WIDTH-1:0] value_1;
        logic [DATA_WIDTH-1:0] comma1;
        logic [DATA_WIDTH-1:0] op_0;
        logic [DIGITS-1:0][DATA_WIDTH-1:0] value_0;
        logic [DATA_WIDTH-1:0] msg_close;
    } packet_cfg_t;

    localparam [DATA_WIDTH-1:0] MSG_START_VAL = 8'h7B;
    localparam [DATA_WIDTH-1:0] R_VAL = 8'h52;
    localparam [DATA_WIDTH-1:0] R_SMALL_VAL = 8'h72;
    localparam [DATA_WIDTH-1:0] COMMA_VAL = 8'h2C;
    localparam [DATA_WIDTH-1:0] G_VAL = 8'h47;
    localparam [DATA_WIDTH-1:0] G_SMALL_VAL = 8'h67;
    localparam [DATA_WIDTH-1:0] B_VAL = 8'h42;
    localparam [DATA_WIDTH-1:0] B_SMALL_VAL = 8'h62;
    localparam [DATA_WIDTH-1:0] MSG_CLOSE_VAL = 8'h7D;
    localparam [DATA_WIDTH-1:0] L_VAL = 8'h4C;
    localparam [DATA_WIDTH-1:0] L_SMALL_VAL = 8'h6C;

    // RX result (parser -> gemma_correction, display_ctrl)
    localparam SCREENS_PER_SEGMENT = 2;
    typedef struct packed {
        logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] value_2; //8
        logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] value_1; //8
        logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] value_0; //8
    } pixel_parsed_t;

    // gemma correction (gemma_correction -> cie_scaling)
    // GAMMA_WIDTH is the gamma table width - a constant, it does not follow SLOTS.
    // SLOTS is a chip_top parameter; from the width-extension block onward the
    // signals are plain [SLOTS_WIDTH-1:0] vectors, not a package type.
    localparam GAMMA_WIDTH = 10;
    typedef struct packed {
        logic [GAMMA_WIDTH-1:0] red;
        logic [GAMMA_WIDTH-1:0] green;
        logic [GAMMA_WIDTH-1:0] blue;
    } corrected_pixel_t;



    // Display (rx_display -> seven_segment -> display_ctrl -> pins)
    // Number of anodes for screen
    localparam AN_WIDTH = 8;
    localparam SS_DIG_WIDTH = 7;
    localparam [AN_WIDTH-1:0] AN_RESET_VAL = {{(AN_WIDTH-1){1'b1}}, 1'b0};
    localparam [SS_DIG_WIDTH-1:0] SEG_RESET_VAL = 7'd1;

    typedef struct packed {
        logic [AN_WIDTH-1:0] an;
        logic [SS_DIG_WIDTH-1:0] seg;
        logic dp;
    } display_cfg_t;

    typedef struct packed {
        logic led15, led14, led13, led12, led11, led10, led9, led8, led7, led6, led5, led4, led3, led2, led1, led0;
    } leds_cfg_t;

    // FSM states, in data-flow order
    typedef enum logic [1:0] { DEB_S0, DEB_W1, DEB_S1, DEB_W0 } deb_state_t;
    typedef enum logic { TX_IDLE, TX_TRANSMIT } tx_state_t;
    typedef enum logic [1:0] { RX_PHY_IDLE, RX_PHY_START, RX_PHY_DATA, RX_PHY_STOP } rx_phy_state_t;
    typedef enum logic [1:0] { RX_MAC_IDLE, RX_MAC_OPCODE, RX_MAC_VALUE, RX_MAC_DONE_NEXT } rx_mac_state_t;

endpackage
