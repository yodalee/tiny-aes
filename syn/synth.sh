#!/usr/bin/env bash
set -euo pipefail

# Usage: bash syn/synth.sh [top] [out_dir] verilog_file...
#
# With no Liberty file this produces generic Yosys logic-cell counts, suitable
# for comparing RTL changes. For a tapeout-relevant area report, provide the
# target standard-cell library through LIBERTY.

top="${1:-${TOP:-AesTop}}"
out_dir="${2:-${OUT_DIR:-build/syn}}"
verilog_sources=("${@:3}")
liberty="${LIBERTY:-}"

if (( ${#verilog_sources[@]} == 0 )); then
  printf 'Usage: bash syn/synth.sh [top] [out_dir] verilog_file...\n' >&2
  exit 2
fi

for source in "${verilog_sources[@]}"; do
  if [[ ! -f "${source}" ]]; then
    printf 'Verilog source file not found: %s\n' "${source}" >&2
    exit 2
  fi
done

mkdir -p "${out_dir}"

netlist="${out_dir}/${top}_netlist.v"
flatnetlist="${out_dir}/${top}_flat_netlist.v"
area_report="${out_dir}/${top}_area_stat.rpt"
module_report="${out_dir}/${top}_module_stat.rpt"
module_json="${out_dir}/${top}_module_stat.json"
log="${out_dir}/${top}.log"
script="${out_dir}/${top}.ys"

if [[ -n "${liberty}" ]]; then
  if [[ ! -f "${liberty}" ]]; then
    printf 'LIBERTY file not found: %s\n' "${liberty}" >&2
    exit 2
  fi
  map_cells="dfflibmap -liberty ${liberty}
abc -liberty ${liberty}"
  stat_options="-liberty ${liberty}"
  area_label="standard-cell area"
else
  # ABC's full default script is used (do not add -fast). The generic count
  # is a logic complexity metric, not physical ASIC area.
  map_cells="abc -g all"
  stat_options=""
  area_label="generic logic-cell count"
fi

cat > "${script}" <<YOSYS
read_verilog ${verilog_sources[*]}

# First preserve hierarchy so stat reports a local logic-cell count for every
# elaborated module.
hierarchy -top ${top}
synth -top ${top}
tee -o ${module_report} stat ${stat_options} -top ${top}
tee -o ${module_json} stat -json ${stat_options} -top ${top}
design -save mapped_hier
write_verilog -noattr ${netlist}

# Flatten the mapped hierarchy and rerun global logic optimization. This is
# the lowest-area netlist produced by this generic/Liberty mapping flow.
flatten
opt -full
${map_cells}
opt -full
clean
delete t:\$scopeinfo
tee -o ${area_report} stat ${stat_options} -top ${top}
write_verilog -noattr ${flatnetlist}
YOSYS

yosys -q -l "${log}" "${script}"

printf 'Synthesis target:          %s\n' "${top}"
printf 'Area metric:               %s\n' "${area_label}"
printf 'Optimized netlist:         %s\n' "${netlist}"
printf 'Flattened netlist:         %s\n' "${flatnetlist}"
printf 'Flattened top report:      %s\n' "${area_report}"
printf 'Per-module report:         %s\n' "${module_report}"
printf 'Per-module JSON:           %s\n' "${module_json}"
printf 'Yosys log:                 %s\n' "${log}"
