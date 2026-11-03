#!/usr/bin/env bash
set -euo pipefail

# Usage: bash syn/synth.sh [top] [out_dir]
#
# With no Liberty file this produces generic Yosys logic-cell counts, suitable
# for comparing RTL changes. For a tapeout-relevant area report, provide the
# target standard-cell library, for example:
#   LIBERTY=/path/to/stdcell.lib bash syn/synth.sh AesTop build/syn

top="${1:-${TOP:-AesTop}}"
out_dir="${2:-${OUT_DIR:-build/syn}}"
rtl_dir="${RTL_DIR:-rtl}"
liberty="${LIBERTY:-}"

mkdir -p "${out_dir}"

compat_rtl="${out_dir}/rtl"
netlist="${out_dir}/${top}_netlist.v"
area_report="${out_dir}/${top}_area_stat.rpt"
module_report="${out_dir}/${top}_module_stat.rpt"
module_json="${out_dir}/${top}_module_stat.json"
log="${out_dir}/${top}.log"
script="${out_dir}/${top}.ys"

mkdir -p "${compat_rtl}"
cp "${rtl_dir}"/*.sv "${compat_rtl}/"

# Yosys does not parse unpacked arrays of packed structs. Lower each ControlFsm
# microcode table into an equivalent combinational case function. The later
# memory_map/ABC passes then map that function to ordinary logic cells.
awk '
  BEGIN {
    field_count = split("c_stateen c_srow0 c_srow1 c_srow2 c_isrow0 c_isrow1 c_mixcol c_loadkey c_keyen c_ke0 c_ke1 c_ke2 c_kxor c_add c_sbox c_ikxor c_dec192_keysel", fields, " ")
  }
  /^[[:space:]]*localparam[[:space:]]+CtrlSignals_t[[:space:]]+/ {
    in_lut = 1
    lut_name = $3
    lut_index = 0
    lut_names[lut_name] = 1
    print "function automatic CtrlSignals_t " lut_name "(input logic [5:0] index);"
    print "begin"
    print "    case (index)"
    next
  }
  in_lut && /^[[:space:]]*};/ {
    print "        default: " lut_name " = 0;"
    print "    endcase"
    print "end"
    print "endfunction"
    in_lut = 0
    next
  }
  in_lut {
    entry = $0
    sub(/^[[:space:]]*/, "", entry)
    sub(/,[[:space:]]*$/, "", entry)
    for (field_index = 1; field_index <= field_count; field_index++)
      value[field_index] = 0
    for (field_index = 1; field_index <= field_count; field_index++) {
      field = fields[field_index]
      if (match(entry, field "[[:space:]]*:[[:space:]]*[^,}]+")) {
        value[field_index] = substr(entry, RSTART, RLENGTH)
        sub(/^[^:]*:[[:space:]]*/, "", value[field_index])
      }
    }
    packed = "{"
    for (field_index = 1; field_index <= field_count; field_index++) {
      if (field_index > 1) packed = packed ", "
      packed = packed value[field_index]
    }
    packed = packed "}"
    print "        " lut_index ": " lut_name " = " packed ";"
    lut_index++
    next
  }
  {
    for (name in lut_names)
      gsub(name "\\[i\\]", name "(i)")
    print
  }
' "${rtl_dir}/ControlFsm.sv" > "${compat_rtl}/ControlFsm.sv"

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
read_verilog -sv \\
  ${compat_rtl}/Aes_pkg.sv \\
  ${compat_rtl}/EnableFF.sv \\
  ${compat_rtl}/MuxEnableFF.sv \\
  ${compat_rtl}/PosedgeDetector.sv \\
  ${compat_rtl}/RcLUT.sv \\
  ${compat_rtl}/SboxLut.sv \\
  ${compat_rtl}/SboxArish.sv \\
  ${compat_rtl}/SboxCanright.sv \\
  ${compat_rtl}/MixColumn.sv \\
  ${compat_rtl}/ControlMixColumn.sv \\
  ${compat_rtl}/ControlShiftrow.sv \\
  ${compat_rtl}/AddRoundKey.sv \\
  ${compat_rtl}/KeyExpansion.sv \\
  ${compat_rtl}/AesState.sv \\
  ${compat_rtl}/ControlFsm.sv \\
  ${compat_rtl}/AesCore.sv \\
  ${compat_rtl}/AesTop.sv

# First preserve hierarchy so stat reports a local logic-cell count for every
# elaborated module. The generated ControlFsm case functions below are
# combinational logic, so the microcode LUTs are included in this mapping.
hierarchy -top ${top}
synth -top ${top} -hieropt
tee -o ${module_report} stat ${stat_options} -top ${top}
tee -o ${module_json} stat -json ${stat_options} -top ${top}
design -save mapped_hier

# Flatten the mapped hierarchy and rerun global logic optimization. This is
# the lowest-area netlist produced by this generic/Liberty mapping flow.
flatten
opt -full
${map_cells}
opt -full
clean
delete t:\$scopeinfo
tee -o ${area_report} stat ${stat_options} -top ${top}
write_verilog -noattr ${netlist}
YOSYS

yosys -q -l "${log}" "${script}"

printf 'Synthesis target:          %s\n' "${top}"
printf 'Area metric:               %s\n' "${area_label}"
printf 'Optimized netlist:         %s\n' "${netlist}"
printf 'Flattened top report:      %s\n' "${area_report}"
printf 'Per-module report:         %s\n' "${module_report}"
printf 'Per-module JSON:           %s\n' "${module_json}"
printf 'Yosys log:                 %s\n' "${log}"
