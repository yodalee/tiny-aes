SIM ?= verilator
TEST ?= mixcolumn
SYN_TOP ?= AesTop
SYN_OUT ?= build/syn
SV2V ?= sv2v
OUTPUT_DIR ?= output
AESTOP_RTL_SOURCES := \
	../rtl/EnableFF.sv \
	../rtl/MuxEnableFF.sv \
	../rtl/PosedgeDetector.sv \
	../rtl/SboxArish.sv \
	../rtl/MixColumn.sv \
	../rtl/AesState.sv \
	../rtl/KeyExpansion.sv \
	../rtl/RcLUT.sv \
	../rtl/AddRoundKey.sv \
	../rtl/AesCore.sv \
	../rtl/ControlFsm.sv \
	../rtl/ControlMixColumn.sv \
	../rtl/ControlShiftrow.sv \
	../rtl/AesTop.sv
SV2V_RTL_SOURCES := \
	rtl/EnableFF.sv \
	rtl/MuxEnableFF.sv \
	rtl/RcLUT.sv \
	rtl/SboxArish.sv \
	rtl/MixColumn.sv \
	rtl/AddRoundKey.sv \
	rtl/KeyExpansion.sv \
	rtl/AesState.sv \
	rtl/ControlFsm.sv \
	rtl/AesCore.sv \
	rtl/AesTop.sv
SV2V_OUTPUTS := $(patsubst rtl/%.sv,$(OUTPUT_DIR)/%.v,$(SV2V_RTL_SOURCES))

.PHONY: help output sim sim-aestop sim-mixcolumn sim-controlmixcolumn sim-controlshiftrow sim-sbox sim-sbox-arish sim-sbox-canright sim-% sim-all synth synth-sbox-area clean-sim clean-synth

help:
	@printf 'Targets:\n'
	@printf '  make sim              Run the default simulation (mixcolumn)\n'
	@printf '  make sim TEST=<name>  Run sim/sim_<name>.py\n'
	@printf '  make sim-<name>       Run sim/sim_<name>.py\n'
	@printf '  make sim-<name> DUMP=1  Write an FST trace for any simulation\n'
	@printf '  make sim-all          Run all sim/sim_*.py tests\n'
	@printf '  make output           Convert each AesTop RTL source to a separate Verilog file in $(OUTPUT_DIR)/\n'
	@printf '  make synth            Synthesize RTL with Yosys (SYN_TOP=AesTop)\n'
	@printf '  make synth-sbox-area  Compare Canright and Arish S-box area\n'
	@printf '  make clean-sim        Remove simulation build outputs\n'
	@printf '  make clean-synth      Remove synthesis build outputs\n'

sim: sim-$(TEST)

sim-mixcolumn:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/MixColumn.sv TOPLEVEL=MixColumn COCOTB_TEST_MODULES=sim_mixcolumn

sim-controlmixcolumn:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES='../rtl/PosedgeDetector.sv ../rtl/ControlMixColumn.sv' TOPLEVEL=ControlMixColumn COCOTB_TEST_MODULES=sim_controlmixcolumn

sim-controlshiftrow:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES='../rtl/PosedgeDetector.sv ../rtl/ControlShiftrow.sv' TOPLEVEL=ControlShiftrow COCOTB_TEST_MODULES=sim_controlshiftrow

sim-sboxlut:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/SboxLut.sv TOPLEVEL=SboxLut COCOTB_TEST_MODULES=sim_sbox

sim-sboxarish:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/SboxArish.sv TOPLEVEL=SboxArish COCOTB_TEST_MODULES=sim_sboxarish

sim-sboxcanright:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/SboxCanright.sv TOPLEVEL=SboxCanright COCOTB_TEST_MODULES=sim_sboxcanright

sim-%:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES='$(RTL_SOURCES)' TOPLEVEL='$(TOPLEVEL)' COCOTB_TEST_MODULES=sim_$*

sim-aestop:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES='$(AESTOP_RTL_SOURCES)' TOPLEVEL=AesTop COCOTB_TEST_MODULES=sim_aestop

sim-all:
	@set -e; \
	for test in sim/sim_*.py; do \
		name=$${test#sim/sim_}; \
		name=$${name%.py}; \
		$(MAKE) sim-$$name SIM=$(SIM); \
	done

output: $(SV2V_OUTPUTS)

$(OUTPUT_DIR)/%.v: rtl/%.sv
	mkdir -p $(OUTPUT_DIR)
	$(SV2V) -w $@ $<

clean-sim:
	$(MAKE) -C sim clean

synth:
	bash syn/synth.sh $(SYN_TOP) $(SYN_OUT)

synth-sbox-area:
	bash syn/compare_sbox_area.sh

clean-synth:
	rm -rf $(SYN_OUT)
