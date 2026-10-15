# Chip Design and Verification – course labs

Lab work from the **Google & Reichman Tech School Chip Design & Verification program** (Verilog + Verification track).
Every lab goes through the full FPGA flow: RTL in Verilog, self-checking testbenches, lint, synthesis,
place-and-route, bitstream, and a test on a real **Digilent Nexys A7-100T** (Artix-7 `xc7a100tcsg324-1`).

| Lab | Design | What it covers | Verification | On the board |
|---|---|---|---|---|
| [Lab 1 – UART stub](lab1_uart_stub/) | `chip_top` with `uart_rx` / `uart_tx` stubs | Top-down architecture: block diagram, I/O tables, module stubs, hierarchical integration, lint | lint only (stubs) | – |
| [Lab 2 – 8-bit adder](lab2_adder_8bit/) | Behavioral vs. flat structural ripple-carry adder | Two coding styles for the same function, shared testbench, schematic comparison, resource usage | `$monitor` testbench, both adders side by side | switches → LEDs ✔ |
| [Lab 3 – 7-segment controller](lab3_seven_segment/) | 16-bit value latched by a 1 s button press, shown in decimal or hex on the 8-digit display | Clock dividing, button synchronizing and hold detection, serial double-dabble binary→BCD, display multiplexing | 7 self-checking testbenches, **798/798** checks pass | ✔ (photos) |
| [Lab 4 – TX UART controller](lab4_tx_uart_controller/) | A switch-selected byte sent to the PC as an N×N square over UART (57600 bps, 8N1), configuration and row count on the display | Debounce and 1 s hold, byte-level FSM with an inter-byte WAIT state and registered outputs, bit-level UART PHY with a start/done handshake, three FSMs drawn with their transition tables | 3 self-checking testbenches (driver / monitor / scoreboard in `tb_chip_top`), **12 549/12 549** checks pass | ✔ (photos + terminal log) |

## Tools

* **Vivado 2025.2** – xsim behavioral simulation, lint, elaboration, synthesis, implementation, bitstream
* **Verilator 5** – extra lint pass (`-Wall`)
* **Icarus Verilog** – the testbenches also run on open-source tools, see below
* **draw.io** – block diagrams and state machines (`docs/*.drawio`, with exported PNGs)
* **tio** – serial terminal on macOS for the UART board tests (`--log` keeps what the board sent)

## Running the testbenches without Vivado

Every testbench prints a `PASS`/`FAIL` line per check and a `TEST PASS`/`TEST FAIL` summary.
With [Icarus Verilog](https://steveicarus.github.io/iverilog/) installed:

```sh
./scripts/run_tests.sh          # all labs
./scripts/run_tests.sh lab3     # one lab
```

```
lab3_seven_segment
  tb_ss                  TEST PASS 16/16
  tb_tick_gen            TEST PASS | 19/19
  tb_value_latch         TEST PASS | 6/6
  tb_btn_hold_1s         TEST PASS | 18/18
  tb_binary_2_bcd        TEST PASS | 25/25
  tb_display_ctrl        TEST PASS | 525/525
  tb_chip_top            TEST PASS | 189/189
lab4_tx_uart_controller
  tb_uart_phy            TEST PASS | 32/32
  tb_tx_fsm              TEST PASS | pass=8338 | fail=0
  tb_chip_top            TEST PASS | pass=4179 | fail=0
```

## Layout of each lab

```
labN_<name>/
├── README.md        what was built, how it works, results
├── rtl/             synthesizable Verilog, one module per file
├── tb/              testbenches
├── constraints/     the Nexys A7-100T .xdc with the pins this lab uses enabled
├── docs/            block diagram (.drawio + .png), report
├── reports/ or results/   lint, synthesis, implementation and utilization reports from Vivado
└── board_test/      photos of the design running on the board (Lab 4: also the terminal log)
```

The Vivado project files, build directories and bitstreams are not committed; the `.xdc`, sources and
reports are everything needed to recreate the project.
