package cnt_rgf_pkg;
    import lab7_pkg::*;

    localparam CNT_WIDTH = RGF_DATA_WIDTH;

    typedef struct packed {
        logic addr_err;
    } cnt_status_t;

    localparam [RGF_ADDR_WIDTH-1:0] CNT_RX_PACKET_ADDR = RGF_ADDR_WIDTH'(0);
    localparam [RGF_ADDR_WIDTH-1:0] CNT_TX_PACKET_ADDR = RGF_ADDR_WIDTH'(4);
    localparam [RGF_ADDR_WIDTH-1:0] CNT_COLOR_MSG_ADDR = RGF_ADDR_WIDTH'(8);
    localparam [RGF_ADDR_WIDTH-1:0] CNT_CONFIG_MSG_ADDR = RGF_ADDR_WIDTH'(12);
    localparam [RGF_ADDR_WIDTH-1:0] CNT_STATUS_ADDR = RGF_ADDR_WIDTH'(16);

    localparam CNT_STOP_BIT = 31;
    localparam CNT_START_BIT = 0;
    localparam CNT_STATUS_STOP_BIT = 0;
    localparam CNT_STATUS_START_BIT = 0;

    localparam CNT_RX_PACKET_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam CNT_TX_PACKET_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam CNT_COLOR_MSG_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam CNT_CONFIG_MSG_RESET_VAL = RGF_DATA_WIDTH'(0);
    localparam CNT_STATUS_RESET_VAL = RGF_DATA_WIDTH'(0);

endpackage