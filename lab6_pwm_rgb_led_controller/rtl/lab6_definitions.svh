`ifndef LAB6_DEFINITIONS_SVH
`define LAB6_DEFINITIONS_SVH

`ifdef SIM
    `define BAUD_RATE 6250000
    `define DEB_COUNT 10
    `define DISPLAY_RR 10000000
    `define SLOTS 64
`else
    `define BAUD_RATE 57600
    `define DEB_COUNT 2000000
    `define DISPLAY_RR 4000
    `define SLOTS 1024
`endif 

`endif 
