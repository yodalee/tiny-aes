#!/usr/bin/env bash
set -euo pipefail

# Synthesize each RTL module as a top against the SKY130 HD standard-cell
# library, then report mapped Liberty area.
#
# Overrides:
#   SKY130_PDK=/path/to/skywater-pdk
#   LIBERTY=/path/to/sky130_fd_sc_hd__*.lib
#
# Usage: bash syn/synth-sky130.sh [top] [out_dir] verilog_file...

top="${1:-${TOP:-AesTop}}"
out_dir="${2:-${OUT_DIR:-build/sky130-hd-tt}}"
verilog_sources=("${@:3}")
pdk_root="${SKY130_PDK:-/home/yodalee/hardware/skywater-pdk}"
default_liberty="${pdk_root}/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__tt_025C_1v80.lib"
liberty="${LIBERTY:-${default_liberty}}"

if (( ${#verilog_sources[@]} == 0 )); then
  printf 'Usage: bash syn/synth-sky130.sh [top] [out_dir] verilog_file...\n' >&2
  exit 2
fi

if [[ ! -f "${liberty}" ]]; then
  printf 'Sky130 Liberty file not found: %s\n' "${liberty}" >&2
  printf 'Set SKY130_PDK or LIBERTY to select an installed standard-cell library.\n' >&2
  exit 2
fi

module_names=()
declare -A seen_modules=()
for source in "${verilog_sources[@]}"; do
  if [[ ! -f "${source}" ]]; then
    printf 'Verilog source file not found: %s\n' "${source}" >&2
    exit 2
  fi

  while IFS= read -r line; do
    if [[ "${line}" =~ ^[[:space:]]*module[[:space:]]+([A-Za-z_][A-Za-z0-9_]*) ]]; then
      module="${BASH_REMATCH[1]}"
      if [[ -z "${seen_modules[${module}]:-}" ]]; then
        module_names+=("${module}")
        seen_modules["${module}"]=1
      fi
    fi
  done < "${source}"
done

if [[ -z "${seen_modules[${top}]:-}" ]]; then
  printf 'Top module "%s" was not found in the Verilog sources.\n' "${top}" >&2
  exit 2
fi

mkdir -p "${out_dir}"

netlist="${out_dir}/${top}_netlist.v"
flatnetlist="${out_dir}/${top}_flat_netlist.v"
area_report="${out_dir}/${top}_area_stat.rpt"
module_report="${out_dir}/${top}_module_stat.rpt"
module_json="${out_dir}/${top}_module_stat.json"
module_reports_dir="${out_dir}/${top}_module_stats"
log="${out_dir}/${top}.log"
script="${out_dir}/${top}.ys"

mkdir -p "${module_reports_dir}"

{
  printf 'read_verilog %s\n' "${verilog_sources[*]}"
  printf 'design -save sky130_source_design\n'
  printf 'hierarchy -check -top %s\n' "${top}"
  printf 'synth -top %s\n' "${top}"
  printf 'write_verilog -noattr %s\n' "${netlist}"

  for module in "${module_names[@]}"; do
    module_report_file="${module_reports_dir}/${module}_area_stat.rpt"
    module_json_file="${module_reports_dir}/${module}_area_stat.json"

    printf 'design -load sky130_source_design\n'
    printf 'hierarchy -check -top %s\n' "${module}"
    printf 'synth -top %s\n' "${module}"
    printf 'flatten\n'
    printf 'opt -full\n'
    printf 'dfflibmap -liberty %s\n' "${liberty}"
    printf 'abc -liberty %s\n' "${liberty}"
    printf 'opt -full\n'
    printf 'clean\n'
    printf 'delete t:$scopeinfo\n'
    printf 'tee -o %s stat -liberty %s -top %s\n' \
      "${module_report_file}" "${liberty}" "${module}"
    printf 'tee -o %s stat -json -liberty %s -top %s\n' \
      "${module_json_file}" "${liberty}" "${module}"

    if [[ "${module}" == "${top}" ]]; then
      printf 'tee -o %s stat -liberty %s -top %s\n' \
        "${area_report}" "${liberty}" "${module}"
      printf 'write_verilog -noattr %s\n' "${flatnetlist}"
    fi
  done
} > "${script}"

yosys -q -l "${log}" "${script}"

{
  printf 'Mapped module area (each RTL module synthesized as top; descendants included)\n'
  printf 'Liberty: %s\n\n' "${liberty}"
  printf '%-28s %12s %20s\n' 'Module' 'Cells' 'Area'

  for module in "${module_names[@]}"; do
    module_report_file="${module_reports_dir}/${module}_area_stat.rpt"
    cells="$(awk '/Number of cells:/ { print $NF; exit }' "${module_report_file}")"
    area="$(awk '/Chip area for module/ { print $NF; exit }' "${module_report_file}")"
    if [[ -z "${cells}" || -z "${area}" ]]; then
      printf 'Could not extract mapped area for module "%s" from %s\n' \
        "${module}" "${module_report_file}" >&2
      exit 1
    fi
    printf '%-28s %12s %20s\n' "${module}" "${cells}" "${area}"
  done
} > "${module_report}"

{
  printf '{\n  "modules": [\n'
  for index in "${!module_names[@]}"; do
    module="${module_names[${index}]}"
    module_report_file="${module_reports_dir}/${module}_area_stat.rpt"
    cells="$(awk '/Number of cells:/ { print $NF; exit }' "${module_report_file}")"
    area="$(awk '/Chip area for module/ { print $NF; exit }' "${module_report_file}")"
    separator=','
    if (( index == ${#module_names[@]} - 1 )); then
      separator=''
    fi
    printf '    {"name": "%s", "num_cells": %s, "area": %s}%s\n' \
      "${module}" "${cells}" "${area}" "${separator}"
  done
  printf '  ]\n}\n'
} > "${module_json}"

printf 'Synthesis target:          %s\n' "${top}"
printf 'Liberty:                   %s\n' "${liberty}"
printf 'Optimized netlist:         %s\n' "${netlist}"
printf 'Flattened netlist:         %s\n' "${flatnetlist}"
printf 'Flattened top report:      %s\n' "${area_report}"
printf 'Per-module area summary:   %s\n' "${module_report}"
printf 'Per-module area reports:   %s\n' "${module_reports_dir}"
printf 'Per-module JSON summary:   %s\n' "${module_json}"
printf 'Yosys log:                 %s\n' "${log}"
