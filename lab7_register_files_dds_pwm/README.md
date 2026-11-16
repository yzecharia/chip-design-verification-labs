# Lab 7 – Control register files and a DDS for PWM

Lab 6's RGB LED controller, now controlled from the PC through register files. A `{W<addr>,V<data high>,V<data low>}`
message over UART (57600 bps, 8N1) writes a register and `{R<addr>}` reads one back. The address is 24 bits and the
data is 32 bits. There are four register files:

| Register file | What it holds |
|---|---|
| `led_rgf` | the colour of each LED, power and CIE on / off per LED, the pattern (static, breath, rainbow) |
| `pwm_rgf` | the number of PWM slots, and per colour a DDS register with the step, the speed (x1, x2, x4, x8) and the start phase |
| `cnt_rgf` | counters of RX messages, TX messages, colour messages and bad messages |
| `sys_rgf` | software reset and enable |

A DDS with a 512-entry sine table (`sin_wave_table.sv`) drives the breath and rainbow patterns on `LED16` and `LED17`.
The Lab 6 pixel message `{Rddd,Gddd,Bddd}` and the buttons still work, both go through `led_rgf`.

Verification: 25 testbenches, one per module, with 126 immediate assertions and 20 SVA properties, 0 errors.
Timing is met at 100 MHz with a slack of 0.254 ns after routing.

## Opening the project

This lab is kept as a Vivado project, not in the `rtl/` `tb/` layout of the other labs.

File > Project > Open → `lab7.xpr`. Part `xc7a100tcsg324-1` (Nexys A7-100T).

```
lab7.xpr                   project file
lab7.srcs/sources_1/new/   RTL, packages (*_pkg.sv), register files (*_rgf.sv)
lab7.srcs/sim_1/new/       testbenches
lab7.srcs/constrs_1/new/   NexysA7-100T_Master.xdc
```

Only `lab7.xpr` and `lab7.srcs/` are in the repo. The `.runs`, `.cache`, `.hw` and `.sim` folders come back when
the project opens.

## Other files

| File | What it is |
|---|---|
| `lab7_rgf.xlsx` | the register map: one sheet per register file, with the address, fields and reset value of each register |
| `lab7_tb_split.xlsx` | the list of testbenches and the cases each one checks |
| `gen_sin_values.py`, `table_generator.py` | write the sine table of the DDS (`sin_wave_table.sv`) |
| `uart_demo.py` | sends a fixed sequence of register writes to the board, reads each register back and pauses so I can take a photo |
| `uart_demo_info.txt` | how to run `uart_demo.py` |
| `uart_demo_log.txt` | the log of one run on the board, 0 problems |
