package sys_rgf_pkg;
    import lab7_pkg::*;
    
    typedef struct packed {
        logic reset;
        logic en;
    } sys_ctrl_t;

    typedef struct packed {
        logic msb_addr_err;
        logic addr_err;
    } sys_status_t;

    localparam [RGF_ADDR_WIDTH-1:0] SYS_CTRL_ADDR = RGF_ADDR_WIDTH'(0);
    localparam [RGF_ADDR_WIDTH-1:0] SYS_STATUS_ADDR = RGF_ADDR_WIDTH'(4);

    localparam SYS_RESET_STOP_BIT = 1;
    localparam SYS_RESET_START_BIT = 1;
    localparam SYS_EN_STOP_BIT = 0;
    localparam SYS_EN_START_BIT = 0;
    localparam SYS_CTRL_STOP_BIT = 1;
    localparam SYS_CTRL_START_BIT = 0;

    localparam SYS_MSB_ADDR_ERR_STOP_BIT = 1;
    localparam SYS_MSB_ADDR_ERR_START_BIT = 1;
    localparam SYS_ADDR_ERR_STOP_BIT = 0;
    localparam SYS_ADDR_ERR_START_BIT = 0;
    localparam SYS_STATUS_STOP_BIT = 1;
    localparam SYS_STATUS_START_BIT = 0;

    localparam SYS_CTRL_RESET_VAL = RGF_DATA_WIDTH'(1);
    localparam SYS_STATUS_RESET_VAL = RGF_DATA_WIDTH'(0);

endpackage