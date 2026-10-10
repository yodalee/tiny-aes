#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-build/syn/sbox_area}"

mkdir -p "${out_dir}"

bash syn/synth.sh SboxCanright "${out_dir}/canright" >/dev/null
bash syn/synth.sh SboxArish "${out_dir}/arish" >/dev/null

cells_for() {
  awk '
    $0 == "=== " module " ===" { in_module = 1; next }
    in_module && /Number of cells:/ { print $4; exit }
  ' module="$1" "$2"
}

canright_cells="$(cells_for SboxCanright "${out_dir}/canright/SboxCanright_stat.rpt")"
arish_cells="$(cells_for SboxArish "${out_dir}/arish/SboxArish_stat.rpt")"
delta=$((canright_cells - arish_cells))

cat <<REPORT
S-box area comparison (Yosys generic cell count)
================================================

Module         Cells
------------- -----
SboxCanright  ${canright_cells}
SboxArish     ${arish_cells}

Delta: SboxCanright - SboxArish = ${delta} cells

Reports:
  ${out_dir}/canright/SboxCanright_stat.rpt
  ${out_dir}/arish/SboxArish_stat.rpt
REPORT
