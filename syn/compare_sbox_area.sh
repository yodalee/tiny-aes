#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-build/syn/sbox_area}"

mkdir -p "${out_dir}"

synth_sbox() {
  local top="$1"
  local name="$2"
  local dir="${out_dir}/${name}"
  local report="${dir}/${top}_stat.rpt"

  mkdir -p "${dir}"
  yosys -q -l "${dir}/${top}.log" -p "
    read_verilog -sv rtl/${top}.sv
    hierarchy -top ${top}
    synth -top ${top}
    opt -full
    abc -g all
    opt -full
    clean
    tee -o ${report} stat -top ${top}
    write_verilog -noattr ${dir}/${top}_netlist.v
  "
}

# Synthesize each implementation by itself.  Invoking the full-chip wrapper
# pulls in unrelated RTL and can make this standalone comparison fail.
synth_sbox SboxCanright canright
synth_sbox SboxArish arish
synth_sbox SboxLut lut

cells_for() {
  awk '
    $0 == "=== " module " ===" { in_module = 1; next }
    in_module && $2 == "cells" { print $1; exit }
    in_module && /Number of cells:/ { print $4; exit }
  ' module="$1" "$2"
}

canright_cells="$(cells_for SboxCanright "${out_dir}/canright/SboxCanright_stat.rpt")"
arish_cells="$(cells_for SboxArish "${out_dir}/arish/SboxArish_stat.rpt")"
lut_cells="$(cells_for SboxLut "${out_dir}/lut/SboxLut_stat.rpt")"
delta=$((canright_cells - arish_cells))
canright_lut_delta=$((canright_cells - lut_cells))
arish_lut_delta=$((arish_cells - lut_cells))

cat <<REPORT
S-box area comparison (Yosys generic cell count)
================================================

Module        Cells
------------ -----
SboxCanright  ${canright_cells}
SboxArish     ${arish_cells}
SboxLut       ${lut_cells}

Delta: SboxCanright - SboxArish = ${delta} cells
       SboxCanright - SboxLut   = ${canright_lut_delta} cells
       SboxArish - SboxLut      = ${arish_lut_delta} cells

Reports:
  ${out_dir}/canright/SboxCanright_stat.rpt
  ${out_dir}/arish/SboxArish_stat.rpt
  ${out_dir}/lut/SboxLut_stat.rpt
REPORT
