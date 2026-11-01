`ifndef LAB5_DEFINITIONS_SVH
`define LAB5_DEFINITIONS_SVH

`ifdef SIM
    `define BAUD_RATE 6250000
    `define DEB_COUNT 10
    `define BTN_HOLD_COUNT 20
    `define DELAY_50MS_VAL 10
    `define DISPLAY_RR 10000000
`else
    `define BAUD_RATE 57600
    `define DEB_COUNT 2000000
    `define BTN_HOLD_COUNT 100000000
    `define DELAY_50MS_VAL 5000000
    `define DISPLAY_RR 4000
`endif 





`endif 
