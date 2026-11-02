package lab5_pkg;

    // Global
    // Clock frequency
    localparam CLK_FREQ = 100000000;
    localparam DATA_WIDTH = 8;
    localparam DIG_IN_WIDTH = 4;

    localparam PACKET_SIZE = 16;

    // TB Values
    localparam CLK_PERIOD = 10;

    // UART frame (tx_phy)
    localparam START_BIT_SIZE = 1;
    localparam STOP_BIT_SIZE = 1;
    localparam FRAME_WIDTH = START_BIT_SIZE + DATA_WIDTH + STOP_BIT_SIZE;

    // Switch configuration (debounce_top -> latch -> tx_mac, display_ctrl)
    localparam SIZE_SEL_WIDTH = 2;
    localparam DELAY_SEL_WIDTH = 2;
    localparam MODE_WIDTH = 1;
    localparam SW_WIDTH = DATA_WIDTH + SIZE_SEL_WIDTH + DELAY_SEL_WIDTH + MODE_WIDTH;

    localparam [1:0][DIG_IN_WIDTH-1:0] DELAY_0MS_DISP = 8'h00, DELAY_50MS_DISP = 8'h05, DELAY_100MS_DISP = 8'h10, DELAY_200MS_DISP = 8'h20;

    localparam SIZE_1_VAL = 1, SIZE_32_VAL = 32, SIZE_128_VAL=128, SIZE_256_VAL = 256;
    typedef enum logic [SIZE_SEL_WIDTH-1:0] { SIZE_1, SIZE_32, SIZE_128, SIZE_256 } size_cfg_t;
    typedef enum logic [DELAY_SEL_WIDTH-1:0] { DELAY_0MS, DELAY_50MS, DELAY_100MS, DELAY_200MS } delay_cfg_t;

    typedef struct packed {
        size_cfg_t size; //sw[11:10] -> switches 14-13
        delay_cfg_t delay; //sw[9:8] -> switches 9-8
        logic [1:0][DIG_IN_WIDTH-1:0] data; //sw[7:0] -> switches 7-0
    } sw_cfg_t;

    // For extra switch in chipt_top -> debounce -> latch flow
    typedef struct packed {
        logic mode;
        logic btnc;
        sw_cfg_t cfg;
    } board_in_t;

    // TX path (tx_mac, tx_display)
    localparam SIZE_WIDTH = $clog2(SIZE_256_VAL);
    localparam ROW_SIZE_WIDTH = SIZE_WIDTH + 1;

    localparam [DATA_WIDTH-1:0] SPACE_DATA = 8'h20;
    localparam [DATA_WIDTH-1:0] NEW_LINE_0_DATA = 8'h0D;
    localparam [DATA_WIDTH-1:0] NEW_LINE_1_DATA = 8'h0A;

    // RX message (rx_mac -> parser)
    localparam DIGITS = 3;
    localparam MAX_GROUPS = 3;
    localparam NUM_OF_VALUES = 3;
    typedef struct packed {
        logic [DATA_WIDTH-1:0] msg_start;
        logic [DATA_WIDTH-1:0] r;
        logic [DIGITS-1:0][DATA_WIDTH-1:0] row_index;
        logic [DATA_WIDTH-1:0] comma0;
        logic [DATA_WIDTH-1:0] c;
        logic [DIGITS-1:0][DATA_WIDTH-1:0] col_index;
        logic [DATA_WIDTH-1:0] comma1;
        logic [DATA_WIDTH-1:0] v;
        logic [DIGITS-1:0][DATA_WIDTH-1:0] value;
        logic [DATA_WIDTH-1:0] msg_close;
    } packet_cfg_t;

    localparam [DATA_WIDTH-1:0] MSG_START_VAL = 8'h7B;
    localparam [DATA_WIDTH-1:0] R_VAL = 8'h52;
    localparam [DATA_WIDTH-1:0] R_SMALL_VAL = 8'h72;
    localparam [DATA_WIDTH-1:0] COMMA_VAL = 8'h2C;
    localparam [DATA_WIDTH-1:0] C_VAL = 8'h43;
    localparam [DATA_WIDTH-1:0] C_SMALL_VAL = 8'h64;
    localparam [DATA_WIDTH-1:0] V_VAL = 8'h56;
    localparam [DATA_WIDTH-1:0] V_SMALL_VAL = 8'h76;
    localparam [DATA_WIDTH-1:0] MSG_CLOSE_VAL = 8'h7D;

    // RX result (parser -> display_ctrl -> rx_display)
    localparam SCREENS_PER_SEGMENT = 2;
    typedef struct packed {
        logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] row_index;
        logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] col_index;
        logic [SCREENS_PER_SEGMENT-1:0][DIG_IN_WIDTH-1:0] pixel_value;
    } rx_parsed_t;

    // Display (rx_display, tx_display -> seven_segment -> display_ctrl -> pins)
    // Number of anodes for screen
    localparam AN_WIDTH = 8;
    localparam SS_DIG_WIDTH = 7;
    localparam [SS_DIG_WIDTH-1:0] DASH_VAL = 7'b111_1110; 


    typedef struct packed {
        logic dash;
        logic [DIG_IN_WIDTH-1:0] data_val;
        logic dp;
    } seven_segment_data_t;

    typedef struct packed {
        logic [SS_DIG_WIDTH-1:0] ss_dig;
        logic dp;
    } display_ctrl_data_t;

    typedef struct packed {
        logic [AN_WIDTH-1:0] an;
        logic [SS_DIG_WIDTH-1:0] seg;
        logic dp;
    } display_cfg_t;

    // FSM states, in data-flow order
    typedef enum logic [1:0] { DEB_S0, DEB_W1, DEB_S1, DEB_W0 } deb_state_t;
    typedef enum logic [1:0] { BTN_IDLE, BTN_COUNT, BTN_WAIT } btn_state_t;
    typedef enum logic [2:0] { TX_MAC_IDLE, TX_MAC_DATA, TX_MAC_SPACE, TX_MAC_NEW_LINE_0, TX_MAC_NEW_LINE_1, TX_MAC_DELAY } tx_mac_state_t;
    typedef enum logic { TX_PHY_IDLE, TX_PHY_TRANSMIT } tx_phy_state_t;
    typedef enum logic [1:0] { RX_PHY_IDLE, RX_PHY_START, RX_PHY_DATA, RX_PHY_STOP } rx_phy_state_t;
    typedef enum logic [1:0] { RX_MAC_IDLE, RX_MAC_OPCODE, RX_MAC_VALUE, RX_MAC_DONE_NEXT } rx_mac_state_t;

endpackage
