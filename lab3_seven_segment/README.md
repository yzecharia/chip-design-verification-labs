# Lab 3 – 7-segment display controller

A 16-bit value set on the switches is latched by holding the **center** (decimal) or **down** (hex)
push-button for one second, and shown on the Nexys A7's 8-digit 7-segment display without flicker.
`CPU_RESETN` clears the stored value. Each of the seven modules has its own testbench (`tb_chip_top_0`
for the top level), and the design is lint-clean, synthesized, placed, routed and tested on the board.

![chip_top architecture](docs/chip_top.png)

## Architecture

One 100 MHz clock domain. There is no divided clock: `tick_gen` produces a **one-cycle enable** every
50 000 clocks (2 kHz) and everything slow runs off that tick, which keeps the design on a single clock
tree and out of CDC trouble. The 2 kHz tick scans five digits, so each digit refreshes at 400 Hz – the
lab's no-flicker target. A "1 second" press is simply 2000 of those ticks, so no separate 1 Hz divider
(and its 27-bit counter) is needed.

| Module | Function | Registers |
|---|---|---|
| [`chip_top`](rtl/chip_top.v) | 2-FF synchronizer for `CPU_RESETN`, instantiates everything, `start = pressed_c \| pressed_d` | 2 |
| [`tick_gen`](rtl/tick_gen.v) | 100 MHz → one-clock tick every `MAX_TICK` cycles (2 kHz) | 16 |
| [`btn_hold_1s`](rtl/btn_hold_1s.v) ×2 | 2-FF synchronizer on the raw button, counts ticks while held, one pulse when the count reaches `MAX_COUNT`; releasing early resets the count, bounces are ignored | 13 each |
| [`value_latch`](rtl/value_latch.v) | latches `SW` on a pulse, stores the mode (`dec_hex`); down wins if both are pressed | 17 |
| [`binary_2_bcd`](rtl/binary_2_bcd.v) | serial **double-dabble** 16-bit binary → 5 BCD digits, one bit per clock, 16 clocks | 25 |
| [`display_ctrl`](rtl/display_ctrl.v) | 5-bit one-hot anode ring advanced by the tick, nibble select, 5th digit enabled only in decimal mode, `DP` off | 5 |
| [`seven_segment`](rtl/seven_segment.v) | hex digit → 7 active-low cathodes | 0 |

Parameters make the slow timing simulable: the lab asks for a ~100 ns button hold in simulation.

| Parameter | Hardware | `tb_chip_top_0` | Meaning |
|---|---|---|---|
| `MAX_TICK` | 50 000 | 2 | clocks per tick (2 kHz) |
| `MAX_COUNT` | 2000 | 5 | ticks per "1 second" press |

Design notes that came up while doing it:

* Buttons are asynchronous inputs, so every one of them (and the reset) goes through two flip-flops
  before anything looks at it.
* `binary_2_bcd` only needs the "add 3 if ≥ 5" correction on the four low digits: the ten-thousands
  digit never exceeds 6 for a 16-bit input.
* `display_ctrl`'s anode output is `{3'b111, !dec_hex | ring[4], ring[3:0]}` – the 5th anode is
  gated off in hex mode (four digits suffice for `FFFF`) and in both modes `AN7..AN5` stay off.

## Verification

The testbenches are order 0, as the course requires: one `initial` block drives the inputs in a fixed
sequence, with no tasks, functions or reference model and no self-check. The inputs change on the falling
edge of the clock. I built them like the Lab 4 benches; `seven_segment` is the same module in both labs,
so `tb_seven_segment` is the Lab 4 bench unchanged. I checked every case in the waveforms and in the console
output (`$monitor` / `$display`) and marked it on the screenshot: numbered markers on the events, and a
coloured box with a tag on the signals that show it.
Results summary: [`results/1_simulation/simulation_summary.txt`](results/1_simulation/simulation_summary.txt),
xsim logs in `results/1_simulation/simulation_logs/`, the annotated waveforms and their wave configs next to them.

| Testbench | DUT | Cases | What the waveforms show |
|---|---|---|---|
| [`tb_seven_segment`](tb/tb_seven_segment.v) | `seven_segment` | 16 digits | every hex digit, one waveform row per cathode |
| [`tb_tick_gen_0`](tb/tb_tick_gen_0.v) | `tick_gen` (`MAX_TICK` = 5) | 2 | a one-clock tick every 5 clocks, `counter` 0…4; `reset_n` = 0 at `counter` = 3 skips that tick and the count starts again from 0 |
| [`tb_value_latch_0`](tb/tb_value_latch_0.v) | `value_latch` | 6 | switches change without a press: `sw_reg` stays `0000`; center → `ABCD`, `dec_hex` = 1; down → `FFFF`, `dec_hex` = 0; center → `0309`; both pressed → `5555`, down wins; reset → `0000` |
| [`tb_btn_hold_1s_0`](tb/tb_btn_hold_1s_0.v) | `btn_hold_1s` + `tick_gen` (`MAX_TICK` = 2, `MAX_COUNT` = 5) | 2 presses | `click_sync` follows `click` 2 clocks later; long press: `counter_1s` counts ticks 0…4, one `pressed_1s` pulse, then stops at 5; 6-clock press: `counter_1s` reaches 3, no pulse |
| [`tb_binary_2_bcd_0`](tb/tb_binary_2_bcd_0.v) | `binary_2_bcd` | 3 conversions | 0 after reset; `start` with 12345 and with 65535: `counter` 0…16, one bit per clock, `bcd` = `12345` and `65535` after 16 clocks, held while `shift_16` = 1 |
| [`tb_display_ctrl_0`](tb/tb_display_ctrl_0.v) | `display_ctrl` + `tick_gen` (`MAX_TICK` = 4) | 3 | the anode ring moves one place per tick; hex: `D C B A` on `AN0..AN3` and the 5th place dark (`FF`); decimal: `1 8 9 3 4` with `AN4` on (`EF`); reset in the middle of a scan → back to `AN0`; `DP` stays off |
| [`tb_chip_top_0`](tb/tb_chip_top_0.v) | full system (`MAX_TICK` = 2, `MAX_COUNT` = 5) | 2 runs | BTNC with `SW` = 12345: 5 ticks → `pressed_c` → `sw_reg` = `3039`, `dec_hex` = 1 → 16 shifts → `bcd_val` = `12345`, then `5 4 3 2 1` on `AN0..AN4`; BTND with `SW` = `0309`: hex, `9 0 3 0` on `AN0..AN3`, 5th place dark |
| **total** | | **34** | |

![tb_chip_top_0: center press, 12345 latched and converted to BCD](results/1_simulation/tb_chip_top_0_1_press_decimal.png)

## Lint, synthesis, implementation

Flow summary: [`results/vivado_flow_summary.txt`](results/vivado_flow_summary.txt).

* **Lint**: Vivado linter on `chip_top` with all sub-modules – clean.
* **Elaborated design**: DRC and methodology clean; RTL schematics per module in `results/2_lint_and_rtl/`.
* **Synthesis**: 0 errors, 0 critical warnings; the 4 warnings are `DP` and `AN7..AN5` being driven
  by constants, which is intended.
* **Implementation** (`results/4_implementation/`): all 444 nets routed, DRC clean, the only
  methodology note is the missing I/O delay constraints on the switch/button/segment pins.

| Resource | Used | Available |
|---|---|---|
| Slice LUTs | 80 | 63 400 |
| Flip-flops | 95 (91 in RTL + 4 fan-out replicas of the anode ring made by `opt_design`) | 126 800 |
| CARRY4 | 4 | |
| I/O | 36 | 210 |
| BRAM / DSP | 0 / 0 | |
| Worst setup slack @ 100 MHz | 5.326 ns | |
| Worst hold slack | 0.163 ns | |
| Power (estimate) | 0.109 W | |

**Resource expectations vs. reality**: before opening the reports I counted the registers from the RTL
(91 – exact) and estimated the LUTs per module from the logic; each module was then synthesized
out-of-context to compare. The write-up with the per-module numbers, why `binary_2_bcd` came in under
the estimate and `display_ctrl` over it, and why the full design is smaller than the sum of its modules
is in [`results/5_resource_usage/resource_usage_analysis.md`](results/5_resource_usage/resource_usage_analysis.md).

## On the board

| | | |
|---|---|---|
| ![after programming](board_test/board_1_programmed_00000_dec.jpg) | ![ABCD decimal](board_test/board_2_abcd_dec_43981.jpg) | ![ABCD hex](board_test/board_3_abcd_hex.jpg) |
| programmed, reset value 0 | `SW = ABCD`, center → `43981` | down → `ABCD` |
| ![FFFF decimal](board_test/board_4_ffff_dec_65535.jpg) | ![FFFF hex](board_test/board_5_ffff_hex.jpg) | ![1234 decimal](board_test/board_6_1234_dec_04660.jpg) |
| `FFFF` decimal → `65535` | `FFFF` hex | `1234` decimal → `04660` |

Report (Hebrew, with every waveform and report excerpt): [`docs/lab3_report.pdf`](docs/lab3_report.pdf).

## Files

```
rtl/          7 modules, one per file
tb/           7 testbenches, one per module (tb_chip_top_0 for the top level)
constraints/  nexys_a7_100t.xdc – CLK100MHZ, CPU_RESETN, SW, BTNC, BTND, CA..CG, DP, AN
docs/         block diagram, lab3_report.pdf
results/      1_simulation  2_lint_and_rtl  3_synthesis  4_implementation  5_resource_usage
              vivado_flow_summary.txt  bitstream_summary.txt
board_test/   photos
```
