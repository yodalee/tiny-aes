# AesTop synthesis baseline

This records a generic-cell synthesis baseline for comparing RTL changes. It
is not a physical standard-cell area estimate; use a target Liberty file with
`LIBERTY=...` when measuring technology-specific area.

## Reproduce

Run from the repository root:

```sh
make synth
```

The synthesis flow converts the RTL with `sv2v`, maps the design with Yosys
ABC's generic gates, and writes the reports under `build/syn/`. Baseline
captured from commit `f0a0f03` using Yosys `0.28+6` and sv2v `0.0.13`.

## Results

| Report | Cell count | Meaning |
| --- | ---: | --- |
| `AesTop_module_stat.rpt` hierarchy total | 5,234 | Hierarchical count, including all instantiated descendants |
| `AesTop_area_stat.rpt` | 2,925 | Flattened and globally optimized generic netlist |

Per-module counts from `AesTop_module_stat.rpt` are local to each module;
submodule instances are counted as cells in their parent. The hierarchy total
accounts for each descendant instance.

| Module | Local cells |
| --- | ---: |
| AddRoundKey | 52 |
| AesCore | 43 |
| AesState | 56 |
| AesTop | 4 |
| ControlFsm | 4,044 |
| EnableFF | 8 |
| KeyExpansion | 257 |
| MixColumn | 89 |
| MuxEnableFF | 9 |
| RcLUT | 36 |
| SboxArish | 189 |

The flattened, globally optimized netlist contains:

| Generic cell type | Count |
| --- | ---: |
| `$_ANDNOT_` | 158 |
| `$_AND_` | 346 |
| `$_AOI3_` | 188 |
| `$_AOI4_` | 94 |
| `$_DFFE_PN0N_` | 230 |
| `$_DFFE_PN0P_` | 180 |
| `$_MUX_` | 377 |
| `$_NAND_` | 305 |
| `$_NMUX_` | 105 |
| `$_NOR_` | 69 |
| `$_NOT_` | 59 |
| `$_OAI3_` | 189 |
| `$_OAI4_` | 73 |
| `$_ORNOT_` | 99 |
| `$_OR_` | 128 |
| `$_XNOR_` | 246 |
| `$_XOR_` | 78 |
| `$mux` | 1 |
