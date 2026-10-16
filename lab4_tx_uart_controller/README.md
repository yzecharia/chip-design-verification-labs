# Lab 4 – TX UART controller

The switches select a byte (`SW[7:0]`), an inter-byte delay (`SW[9:8]`: 0, 50, 100 or 200 ms) and a
square size (`SW[14:13]`: N = 1, 32, 128 or 256). Holding the **center** button for one second latches
them, and the board sends an **N×N square** of that byte to the PC over the on-board USB-UART at
57600 bps, 8N1: a space (`0x20`) after every byte, `CR LF` (`0x0D 0x0A`) at the end of every row.
The 8-digit display shows the configuration and the number of rows sent, and `LED0` toggles with every
data byte. Each of the nine modules has its own testbench (`tb_chip_top_0` for the top level), and the design
is lint-clean, synthesized, placed, routed and tested on the board.

![chip_top architecture](docs/chip_top.png)

## Architecture

Everything runs on one 100 MHz clock, I didn't divide the clock for anything slow: the UART bit rate and the
display scan are **one-cycle enables** from `baud_gen`, and the 20 ms debounce, the 1 s hold and the inter-byte delay are
counters in the same domain. The path from the button to the line is
`debounce → btn_hold → latch → tx_fsm → uart_phy`, with a `start`/`done` handshake between the byte-level
FSM and the bit-level PHY.

| Module | Function | Registers |
|---|---|---|
| [`chip_top`](rtl/chip_top.v) | instantiates everything; parameters for hardware / simulation timing | 0 |
| [`debounce`](rtl/debounce.v) | 2-FF synchronizer + change detector + 20 ms stability counter, one branch for `CPU_RESETN` (→ `reset_n`) and one for `{SW, BTNC}` | 98 |
| [`btn_hold`](rtl/btn_hold.v) | FSM `IDLE → COUNT → WAIT`: one-clock `held` pulse when `BTNC` has been held for 1 s, nothing more until it is released | 29 |
| [`latch`](rtl/latch.v) | latches data, delay and size on `held & ready` and issues a one-clock `transmit` | 13 |
| [`tx_fsm`](rtl/tx_fsm.v) | byte-level FSM `IDLE / DATA / SPACE / NEW_LINE_0 / NEW_LINE_1 / WAIT`: column, row and delay counters, registered `start` / `drive_data` / `LED0` | 58 |
| [`uart_phy`](rtl/uart_phy.v) | bit-level 8N1 transmitter: 10-bit shift register loaded with `{1, data, 0}`, bit counter, its own `baud_gen` | 25 |
| [`baud_gen`](rtl/baud_gen.v) ×2 | one-clock tick every `100 MHz / BAUD_RATE` clocks: 1736 for the UART, 25 000 for the 4 kHz display scan | 11 / 15 |
| [`display_ctrl`](rtl/display_ctrl.v) | 8-bit anode ring, T0 = byte, T1 = delay (`0.0 / 0.5 / 1.0 / 2.0`), T2 = N, T3 = rows sent | 8 |
| [`seven_segment`](rtl/seven_segment.v) | hex digit → 7 active-low cathodes | 0 |

State diagrams of the three state machines:
[`fsm_tx_fsm`](docs/fsm_tx_fsm.png), [`fsm_uart_phy`](docs/fsm_uart_phy.png), [`fsm_btn_hold`](docs/fsm_btn_hold.png);
the transition tables are in the report.

![tx_fsm state diagram](docs/fsm_tx_fsm.png)

Parameters make the slow timing simulable:

| Parameter | Hardware | `tb_chip_top_0` | Meaning |
|---|---|---|---|
| `BAUD_RATE` | 57 600 | 10 000 000 | UART bit rate (10 clocks per bit in simulation) |
| `DISPLAY_RR` | 4 000 | 10 000 000 | display scan tick rate (4 kHz → 500 Hz per digit) |
| `MAX_COUNT_DEBOUNCE` | 2 000 000 | 4 | clocks an input must be stable (20 ms) |
| `MAX_COUNT_BTN_HOLD` | 100 000 000 | 10 | clocks `BTNC` must be held (1 s) |
| `DELAY50` | 5 000 000 | 20 | clocks of the 50 ms delay; 100 / 200 ms are ×2 / ×4 |

Design notes that came up while doing it:

* Checking the baud error: `COUNT = 100M / 57600 = 1736.11` and the integer division keeps 1736, so the actual baud is
  `100M / 1736 = 57 603.69 bps` and the error is `(57 603.69 − 57 600) / 57 600 = +0.0064 %`. The receiver samples each bit
  in its middle, so the error adds up until the stop bit, 9.5 bits after the start edge: `9.5 · 0.0064 % ≈ 0.06 %` of a bit,
  far from the half bit where it would read the wrong bit.
* The switches are sampled only when `tx_fsm` is idle (`ready`), so a press during a run is ignored
  and a run is never reconfigured half way.
* `tx_fsm` moves on only at `uart_phy`'s `done`, and `start`, `drive_data` and `LED0` are registered outputs.
  `WAIT` follows every space and every `CR LF` except the last one; with delay 0 it lasts one clock.
* The row counter is 9 bits wide because N = 256 needs the value 256; T3 shows `FF` once bit 8 is set,
  and T2 shows `FF` for N = 256 as well.
* `dp` is wired to `AN3`, so the decimal point lights on the T1 digit that needs it (`2.0`).

## Verification

The testbenches are order 0, as the course requires: one `initial` block drives the inputs in a fixed
sequence, with no tasks, functions or reference model and no self-check. The inputs change on the falling
edge of the clock. I checked every case in the waveforms and in the console output (`$monitor` / `$display`)
and marked it on the screenshot: numbered markers on the events, and a coloured box with a tag on the signals
that show it.
Results summary: [`results/1_simulation/simulation_summary.txt`](results/1_simulation/simulation_summary.txt),
xsim logs in `results/1_simulation/simulation_logs/`, the annotated waveforms and their wave configs next to them.

| Testbench | DUT | Cases | What the waveforms show |
|---|---|---|---|
| [`tb_debounce`](tb/tb_debounce.v) | `debounce` (`MAX_COUNT` = 10) | 6 | power-on reset: `cpu_reset_d` = 0 until `reset_cnt` counts 0…9; `sw` = `ABC` stable → `sw_d` = `ABC` 13 clocks later; a 9-clock glitch restarts the counter and `sw_d` stays `ABC`; the same for `btnc`; `cpu_reset` → `sw_d` and `btnc_d` cleared |
| [`tb_btn_hold`](tb/tb_btn_hold.v) | `btn_hold` (`MAX_COUNT` = 10) | 2 presses | long press: `COUNT`, `cnt` 0…9, one `held` pulse, `WAIT` until release; 8-clock press: back to `IDLE`, no `held` |
| [`tb_latch`](tb/tb_latch.v) | `latch` | 5 | `held & ready` loads data, delay and size and gives a one-clock `transmit` (`ABC`, `555`, `111`); `ready` without `held` and `held` without `ready` load nothing |
| [`tb_tx_fsm_0`](tb/tb_tx_fsm_0.v) | `tx_fsm` + `uart_phy` (`DELAY50` = 10) | 3 runs | 1×1 of `0x41`: `41 0D 0A`, back to `IDLE` with no `WAIT`; 32×32 of `0x55`, delay 1: a 10-clock `WAIT` after the row end; 32×32 of `0xAA`, delay 3: a 40-clock `WAIT` after a space; `row_out` = 1, 32, 32 |
| [`tb_uart_phy_0`](tb/tb_uart_phy_0.v) | `uart_phy` (10 clocks per bit) | 3 bytes | frame of `0xA5`: start bit, `1 0 1 0 0 1 0 1` LSB first, stop bit, `done` for one clock at `cnt` = 9; `0x00` and `0xFF` in the log |
| [`tb_baud_gen`](tb/tb_baud_gen.v) | `baud_gen` (`BAUD_RATE` = 10M) | 2 | `en` = 1: a one-clock tick every 10 clocks; `en` = 0: `tick_cnt` stays 0 |
| [`tb_seven_segment`](tb/tb_seven_segment.v) | `seven_segment` | 16 digits | every hex digit, one waveform row per cathode |
| [`tb_display_ctrl`](tb/tb_display_ctrl.v) | `display_ctrl` + `baud_gen` (10M) | 20 | anode ring `FE → FD → … → 7F → FE`, one step per tick; delay decode `00 05 10 20`, size decode `01 20 80 FF`; `dp` = 0 only on `AN3`; `row` = `0FF` and `100` both shown as `FF` |
| [`tb_chip_top_0`](tb/tb_chip_top_0.v) | full system (simulation parameters) | 2 runs | an 11-clock press → `btnc_d` 7 clocks later → `held` → `transmit` → the first start bit; the display scan after a 32×32 run of `0x23` with delay 1: T0 = `23`, T1 = `0.5`, T2 = `20`, T3 = `20` |
| **total** | | **59** | |

![tb_tx_fsm_0: end of a row and the WAIT state](results/1_simulation/tb_tx_fsm_0_2_row_end_wait.png)

## Lint, synthesis, implementation

* **Lint**: Vivado linter on `chip_top` with all sub-modules – 0 violations.
* **Elaborated design**: DRC clean; one methodology advisory (`RFFI-1`: `an_reg[3]` drives both `an[3]`
  and `dp`), which is intended – `opt_design` replicates the anode registers anyway. RTL schematics per
  module in `results/2_lint_and_rtl/`.
* **Synthesis**: 0 errors, 0 critical warnings, 0 warnings. Vivado recognised the `btn_hold` and
  `tx_fsm` state machines and re-encoded `tx_fsm` as one-hot.
* **Implementation** (`results/4_implementation/`): 0 errors, 0 critical warnings, 0 warnings;
  all 432 routable nets routed, DRC and methodology clean. Critical path: `latch_i/delay_reg[1]` →
  the `delay_cnt` compare (CARRY4 chain) → `tx_fsm_i/drive_data_reg[0]/CE`, 7.376 ns, 9 logic levels.

| Resource | Used | Available |
|---|---|---|
| Slice LUTs | 164 (170 after synthesis) | 63 400 |
| Flip-flops | 255 (246 in RTL + 9 replicas of the anode registers made by `opt_design`: one per `AN` pin and one more for `dp`) | 126 800 |
| CARRY4 | 41 | |
| I/O | 33 | 210 |
| BRAM / DSP | 0 / 0 | |
| Worst setup slack @ 100 MHz | 2.264 ns | |
| Worst hold slack | 0.122 ns | |
| Power (estimate) | 0.100 W | |

I also synthesized each module out-of-context, the per-module numbers are in
[`results/5_resource_usage/per_module_out_of_context/summary.txt`](results/5_resource_usage/per_module_out_of_context/summary.txt).
The four long counters (two in `debounce`, the 1 s hold and the 200 ms delay) are 94 of the 246 flip-flops.
`tx_fsm` has 58 and not the 55 in the RTL because Vivado re-encoded its state one-hot (6 bits instead of 3), and
`uart_phy` has 25 and not 26 because `sh_reg[9]` is always 1 and Vivado removes it.

## On the board

On macOS I used [tio](https://github.com/tio/tio) as the terminal. It also logs everything the board sends:

```sh
tio -b 57600 --log --log-file "$PWD/output.txt" --log-strip /dev/cu.usbserial-210292BE39B31
```

In the photos I marked each switch group in the colour of the display field it sets. The byte is `0x23` (`#`) in all the cases.

| | | |
|---|---|---|
| ![after programming](board_test/board_1_programmed_done_led.jpg) | ![1x1](board_test/board_2_1x1_hash.jpg) | ![32x32](board_test/board_3_32x32_hash.jpg) |
| programmed: `DONE` on, reset state | 1×1 – one `#`, then `CR LF` | 32×32 – display and terminal |
| ![256x256](board_test/board_4_256x256_hash.jpg) | ![32x32 with 200 ms delay](board_test/board_5_32x32_delay_200ms.jpg) | |
| 256×256 – T3 mid-run (`29` = 41 rows), then saturated at `FF` | 32×32, 200 ms – one row every ~6.4 s, `LED0` blinks per byte | |

The terminal log [`board_test/output.txt`](board_test/output.txt) holds six more runs: 1×1, 32×32, 128×128 and
256×256 of `#`, and 32×32 and 128×128 of `$`. Every run is an exact N×N square (N bytes per row with single
spaces and no trailing space, N rows) – 100 353 data bytes, no errors.

Submitted report (Hebrew, with every waveform, FSM transition table and report excerpt): [`docs/lab4_report.pdf`](docs/lab4_report.pdf).

## Files

```
rtl/          9 modules, one per file
tb/           9 testbenches, one per module (tb_chip_top_0 for the top level)
constraints/  nexys_a7_100t.xdc – CLK100MHZ, CPU_RESETN, BTNC, SW[9:0], SW[14:13], LED0, CA..CG, DP, AN, UART_RXD_OUT
docs/         block diagram, the three FSM diagrams, lab4_report.pdf
results/      1_simulation  2_lint_and_rtl  3_synthesis  4_implementation  5_resource_usage
              bitstream_summary.txt
board_test/   annotated photos, output.txt (tio log)
```
