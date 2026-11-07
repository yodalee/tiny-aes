#!/usr/bin/env bash
set -euo pipefail

# Synthesize against the SkyWater SKY130 HD standard-cell library.
#
# Overrides:
#   SKY130_PDK=/path/to/skywater-pdk
#   LIBERTY=/path/to/sky130_fd_sc_hd__*.lib
#
# Usage: bash syn/synth-sky130.sh [top] [out_dir]

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pdk_root="${SKY130_PDK:-/home/yodalee/hardware/skywater-pdk}"
default_liberty="${pdk_root}/libraries/sky130_fd_sc_hd/latest/timing/sky130_fd_sc_hd__tt_025C_1v80.lib"
liberty="${LIBERTY:-${default_liberty}}"

if [[ ! -f "${liberty}" ]]; then
  printf 'Sky130 Liberty file not found: %s\n' "${liberty}" >&2
  printf 'Set SKY130_PDK or LIBERTY to select an installed standard-cell library.\n' >&2
  exit 2
fi

LIBERTY="${liberty}" exec bash "${script_dir}/synth.sh" "$@"
