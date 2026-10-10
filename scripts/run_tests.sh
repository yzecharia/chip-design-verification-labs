#!/usr/bin/env bash
# Runs every self-checking testbench in this repo with Icarus Verilog (open source),
# so the results can be reproduced without Vivado.
#   ./scripts/run_tests.sh           # run everything
#   ./scripts/run_tests.sh lab3      # one lab
# Needs: iverilog + vvp (brew install icarus-verilog / apt install iverilog)
set -u
cd "$(dirname "$0")/.."
OUT=sim_out; mkdir -p "$OUT"
status=0

run() { # run <name> <top> <files...>
    local name=$1 top=$2; shift 2
    if iverilog -g2012 -s "$top" -o "$OUT/$name.vvp" "$@" 2>"$OUT/$name.compile.log" \
       && vvp -n "$OUT/$name.vvp" >"$OUT/$name.log" 2>&1; then
        if grep -q 'TEST PASS' "$OUT/$name.log"; then
            printf '  %-22s %s\n' "$name" "$(grep -o 'TEST PASS.*' "$OUT/$name.log" | tail -1)"
        elif grep -q 'TEST FAIL' "$OUT/$name.log"; then
            printf '  %-22s FAIL  (see %s/%s.log)\n' "$name" "$OUT" "$name"; status=1
        else
            printf '  %-22s ran   (see %s/%s.log)\n' "$name" "$OUT" "$name"
        fi
    else
        printf '  %-22s COMPILE/RUN ERROR (see %s/%s.*.log)\n' "$name" "$OUT" "$name"; status=1
    fi
}

want=${1:-all}

if [[ $want == all || $want == lab2 ]]; then
    echo "lab2_adder_8bit"
    run tb_fa_8 tb_fa_8 lab2_adder_8bit/rtl/fa_8_behavioral.v lab2_adder_8bit/rtl/fa_8_structural_flat.v lab2_adder_8bit/tb/tb_fa_8.v
    # the exhaustive 255x255x2 run prints ~130k lines; kept out of the default run
fi

if [[ $want == all || $want == lab3 ]]; then
    echo "lab3_seven_segment"
    for tb in tb_ss tb_tick_gen tb_value_latch tb_btn_hold_1s tb_binary_2_bcd tb_display_ctrl tb_chip_top; do
        run "$tb" "$tb" lab3_seven_segment/rtl/*.v "lab3_seven_segment/tb/$tb.v"
    done
fi

exit $status
