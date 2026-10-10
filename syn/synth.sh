#!/usr/bin/env bash
set -euo pipefail

top="${1:-${TOP:-AesTop}}"
out_dir="${2:-${OUT_DIR:-build/syn}}"
rtl_dir="${RTL_DIR:-rtl}"

mkdir -p "${out_dir}"

compat_rtl="${out_dir}/rtl"
netlist="${out_dir}/${top}_netlist.v"
report="${out_dir}/${top}_stat.rpt"
log="${out_dir}/${top}.log"
script="${out_dir}/${top}.ys"

rm -rf "${compat_rtl}"
mkdir -p "${compat_rtl}"
cp "${rtl_dir}"/*.sv "${compat_rtl}/"

# Yosys 0.28 does not parse package imports at file scope. Keep source RTL
# unchanged and synthesize a generated compatibility copy instead.
awk '
  /^import AesPkg::kLevel128;/ { next }
  /^import AesPkg::kLevel192;/ { next }
  /^module KeyExpansion[[:space:]]*\(/ { in_header = 1 }
  { print }
  in_header && /^\);/ {
    print ""
    print "localparam logic [1:0] kLevel128 = 2'\''b00;"
    print "localparam logic [1:0] kLevel192 = 2'\''b01;"
    in_header = 0
  }
' "${rtl_dir}/KeyExpansion.sv" > "${compat_rtl}/KeyExpansion.sv"

cat > "${script}" <<YOSYS
read_verilog -sv \\
  ${compat_rtl}/Aes_pkg.sv \\
  ${compat_rtl}/EnableFF.sv \\
  ${compat_rtl}/MuxEnableFF.sv \\
  ${compat_rtl}/PosedgeDetector.sv \\
  ${compat_rtl}/RcLUT.sv \\
  ${compat_rtl}/Sbox.sv \\
  ${compat_rtl}/SboxArish.sv \\
  ${compat_rtl}/SboxCanright.sv \\
  ${compat_rtl}/MixColumn.sv \\
  ${compat_rtl}/AddRoundKey.sv \\
  ${compat_rtl}/KeyExpansion.sv \\
  ${compat_rtl}/AesState.sv \\
  ${compat_rtl}/ControlFsm.sv \\
  ${compat_rtl}/AesCore.sv \\
  ${compat_rtl}/AesTop.sv

hierarchy -top ${top}
synth -top ${top}

# Keep hierarchy intact, but spend more effort minimizing each module. The
# default synth flow uses abc -fast; this remaps with ABC's fuller script and
# the complete generic gate set so S-box implementations can shrink further.
opt -full
abc -g all
opt -full
clean
tee -o ${report} stat -top ${top}
write_verilog -noattr ${netlist}
YOSYS

yosys -q -l "${log}" "${script}"

printf 'Wrote synthesized netlist: %s\n' "${netlist}"
printf 'Wrote synthesis report:    %s\n' "${report}"
printf 'Wrote synthesis log:       %s\n' "${log}"
