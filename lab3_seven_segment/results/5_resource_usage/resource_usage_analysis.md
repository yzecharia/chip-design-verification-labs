# Lab 3 – Resource usage: STAGE 2 (check yourself AFTER filling in the stage-1 worksheet)

Target: Nexys A7-100T, **xc7a100tcsg324-1** (63,400 LUTs, 126,800 flip-flops, 210 I/O pins, 240 DSP, 135 BRAM36).
Tool: Vivado 2025.2, default synthesis / implementation strategies.

**Every number below is taken from the `.rpt` files** (`utilization_synth.rpt`, `utilization_placed.rpt`,
`per_module_out_of_context/utilization_<module>.rpt`), not from the flow's text summaries. The flow summaries
(`vivado_flow_SUMMARY.txt`, `synthesis_summary.txt`, `implementation_summary.txt`) print "110 LUT": that is the number
of LUT *primitives* (LUT1..LUT6 cells). `report_utilization` counts *slice LUTs* after LUT combining: two primitives
that share one physical LUT (a LUT5 + LUT6 pair "using O5 and O6") count once. Full design: 110 primitives = 83 slice
LUTs after synthesis (27 combined pairs) and 80 slice LUTs after placement (30 combined pairs).

## 2.1 Flip-flops – the exact answer

| Module (instances) | Registers in the RTL | FFs | Synthesized OOC (.rpt) |
|---|---|---|---|
| chip_top (1) | reset_n_sync0, reset_n_sync (2-stage CPU_RESETN synchronizer) | 2 | 2 (in top) |
| tick_gen (1) | counter[15:0] – ⌈log2(50000)⌉ = 16 | 16 | 16 |
| btn_hold_1s (2) | click_sync0, click_sync + counter_1s[10:0] – ⌈log2(2001)⌉ = 11 → 13 each | 26 | 13 each |
| value_latch (1) | sw_reg[15:0] + dec_hex | 17 | 17 |
| binary_2_bcd (1) | 5 digit registers × 4 bits + counter[4:0] | 25 | 25 |
| display_ctrl (1) | ring_reg[4:0] | 5 | 5 |
| seven_segment (1) | none – combinational | 0 | 0 |
| **Total** | | **91** | **91 synthesized / 95 placed** |

Vivado's RTL statistics confirm the inventory: one 16-bit, two 11-bit, two 5-bit, five 4-bit and seven 1-bit registers.
`Register as Latch = 0`. Registers that reset to 1: ring_reg[4:1] (reset value 11110) → 4 FDSE, all others FDRE.

**91 → 95 after implementation.** Comparing the synthesized and the routed checkpoint cell lists shows exactly which
cells were added: `display_ctrl_i/ring_reg_reg[0..3]_lopt_replica`. `opt_design` ("Phase Sweep created 4 cells")
replicated the four scan-ring bits because each one drives both an anode output buffer and ~20 LUTs of the digit
multiplexer; the replica drives the pins, the original drives the logic. It is a fanout optimization, not a functional
change, and it is why the placed design has 7 FDSE (ring_reg[4:1] plus the replicas of bits 3..1).

## 2.2 LUTs – one way to estimate, and the out-of-context result of each module (slice LUTs from the .rpt files)

| Module | Logic | Estimate | OOC slice LUTs | Other primitives |
|---|---|---|---|---|
| tick_gen | 16-bit +1 on a carry chain, compare == 49999, synchronous clear | 4 CARRY4 + 6–8 | 7 | 4 CARRY4 |
| btn_hold_1s (each) | 11-bit +1 with enable and saturation (== 2000), compare == 1999, clear on !click_sync, output AND | 12–18 | 15 | – (11-bit adder built from LUTs, no carry chain) |
| value_latch | clock enable pressed_c \| pressed_d, dec_hex set/clear | 2–3 | 3 | – |
| binary_2_bcd | 4 × "add 3 if ≥ 5" on 4 bits ≈ 12–16, 16:1 bit selector sw[15-counter] ≈ 4–5, 5-bit counter + == 16 ≈ 3–4 | 20–26 | 17 | 2 MUXF7, 1 MUXF8 (the 16:1 selector) |
| display_ctrl (incl. seven_segment) | 20-bit 2:1 mux + 5:1 nibble select ≈ 16–20, anode logic 1, 7-segment decoder 7 | 25–30 | 37 | – |
| seven_segment alone | 7 outputs, each a function of 4 inputs → 7 × LUT4 | 7 | 7 | – |
| **Sum of modules** (display_ctrl already contains the decoder) | | **≈ 85–105** | **94** | 4 CARRY4, 2 MUXF7, 1 MUXF8 |
| **Full design in context** | cross-boundary optimization | fewer than the sum | **83 synth / 80 placed** | 4 CARRY4, 1 MUXF7 |

Points to compare with your own estimate:

* binary_2_bcd came in *below* a naive estimate (17): after the shift, only 3 bits of each "add 3" result are kept, and
  the 16:1 bit selector is built from 4 LUT6 + MUXF7/MUXF8 instead of plain LUTs.
* display_ctrl came in *above* (37): the `case (ring_reg)` has a `default` branch, so Vivado decodes the whole 5-bit
  pattern for each output bit instead of using the one-hot bits directly as mux selects. At 0.06 % of the device this
  was not worth restructuring, but a `case` on the one-hot index (or a priority-free and-or mux) would be smaller.
* The full design (80) is smaller than the sum of the modules (94): constants are propagated (DP, AN7..AN5 are tied
  off), the two btn_hold_1s instances share the tick and reset terms, and display_ctrl's inputs are registers rather
  than free ports.

## 2.3 Actual usage of the implemented design (utilization_placed.rpt)

| Resource | Used | Available | Utilization |
|---|---|---|---|
| Slice LUTs (all as logic; 110 LUT primitives, 30 dual-output pairs) | 80 | 63,400 | 0.13 % |
| Slice registers (all flip-flops, 0 latches) | 95 | 126,800 | 0.07 % |
| Slices occupied (27 SLICEL + 8 SLICEM) | 35 | 15,850 | 0.22 % |
| CARRY4 | 4 | 15,850 | 0.03 % |
| F7 muxes | 1 | 31,700 | < 0.01 % |
| Block RAM / DSP48 | 0 / 0 | 135 / 240 | 0 % |
| Bonded IOB (20 inputs + 16 outputs) | 36 | 210 | 17.14 % |
| BUFGCTRL (CLK100MHZ only, no MMCM/PLL) | 1 | 32 | 3.13 % |
| Unique control sets | 9 | | |

Primitives (placed): FDRE 88, FDSE 7, LUT6 37, LUT4 37, LUT5 16, LUT2 11, LUT3 6, LUT1 3, CARRY4 4, MUXF7 1, IBUF 20,
OBUF 16, BUFG 1. Synthesis (before placement): 83 slice LUTs, 91 FFs (87 FDRE + 4 FDSE).

I/O: 36 pins = CLK100MHZ, CPU_RESETN, BTNC, BTND, SW[15:0] (20 inputs) and DP, ss_dig[6:0], disp_an[7:0]
(16 outputs) – exactly the interface in the lab requirements. disp_an[7:5] and DP are constant 1 (always off); synthesis
reports that as 4 benign warnings.

## 2.4 Timing and power (timing_summary_routed.rpt, power_routed.rpt)

* Clock: sys_clk_pin 10.000 ns (100 MHz) on CLK100MHZ, from the master XDC.
* Setup: WNS = **+5.326 ns**, TNS = 0 over 237 endpoints. Critical path: tick_gen counter_reg[3] → tick →
  value_latch sw_reg[11] clock-enable, 4 LUT levels, 4.397 ns (78 % routing). The design would close timing up to
  ≈ 1/(10 − 5.326 ns) ≈ 214 MHz.
* Hold: WHS = **+0.163 ns**, THS = 0. Pulse width: WPWS = +4.500 ns.
* 184 routable nets, all routed, 0 routing errors.
* Power estimate: 0.109 W total = 0.097 W static + 0.011 W dynamic (0.010 W of it in the I/O). Junction 25.5 °C.

## 2.5 Design decision: 1 s from the 2 kHz tick instead of a 1 Hz divider

A 1 Hz pulse straight from 100 MHz needs a 27-bit counter (100,000,000 cycles ≈ 27 FFs + 7 CARRY4). Counting
2000 ticks of the existing 2 kHz tick needs an 11-bit counter – 16 FFs and all carry chains saved per button – and,
more important, keeps a single clock domain: the tick is a synchronous enable, so no clock-domain crossing, no extra
BUFG and no derived-clock timing constraints.
