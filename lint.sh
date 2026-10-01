#!/usr/bin/env bash

# Lint every Verilog and SystemVerilog source under rtl/.
set -euo pipefail

mapfile -t rtl_sources < <(find rtl -type f \( -name '*.v' -o -name '*.sv' \) -print | sort)

if (( ${#rtl_sources[@]} == 0 )); then
    printf 'No Verilog or SystemVerilog sources found under rtl/.\n' >&2
    exit 1
fi

verilator --lint-only --sv -Wno-MULTITOP "${rtl_sources[@]}"
