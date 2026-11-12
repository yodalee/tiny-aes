SIM ?= verilator
TEST ?= mixcolumn
SYN_TOP ?= AesTop
SYN_OUT ?= build/syn
SYN_SKY_OUT ?= build/sky130-hd-tt
SKY130_PDK ?= /home/yodalee/hardware/skywater-pdk
SV2V ?= sv2v
OUTPUT_DIR ?= output
AESTOP_RTL_SOURCES := \
	../rtl/EnableFF.sv \
	../rtl/MuxEnableFF.sv \
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

.PHONY: help output
.PHONY: sim sim-all
.PHONY: sim-aestop sim-mixcolumn sim-controladd sim-controlmixcolumn
.PHONY: sim-controlshiftrow sim-controlkeyexpand sim-sbox sim-sboxlut
.PHONY: sim-sboxarish sim-sboxcanright
.PHONY: synth synth-sky synth-sbox-area clean-sim clean-synth
.PHONY: FORCE

FORCE:

help:
	@printf 'Targets:\n'
	@printf '  make sim              Run the default simulation (mixcolumn)\n'
	@printf '  make sim TEST=<name>  Run sim/sim_<name>.py\n'
	@printf '  make sim-<name>       Run sim/sim_<name>.py\n'
	@printf '  make sim-<name> WAVES=1  Write an FST trace for the simulation\n'
	@printf '  make sim-all          Run all sim/sim_*.py tests\n'
	@printf '  make output           Convert each AesTop RTL source to a separate Verilog file in $(OUTPUT_DIR)/\n'
	@printf '  make synth            Synthesize RTL with Yosys (SYN_TOP=AesTop)\n'
	@printf '  make synth-sky        Synthesize with SKY130 HD TT (SKY130_PDK=/path/to/pdk)\n'
	@printf '  make synth-sbox-area  Compare Canright and Arish S-box area\n'
	@printf '  make clean-sim        Remove simulation build outputs\n'
	@printf '  make clean-synth      Remove synthesis build outputs\n'

sim: sim-$(TEST)

sim-mixcolumn:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/MixColumn.sv TOPLEVEL=MixColumn COCOTB_TEST_MODULES=sim_mixcolumn

sim-controlmixcolumn:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/ControlMixColumn.sv TOPLEVEL=ControlMixColumn COCOTB_TEST_MODULES=sim_controlmixcolumn

sim-controlshiftrow:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/ControlShiftrow.sv TOPLEVEL=ControlShiftrow COCOTB_TEST_MODULES=sim_controlshiftrow

sim-controlkeyexpand:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/ControlKeyExpand.sv TOPLEVEL=ControlKeyExpand COCOTB_TEST_MODULES=sim_controlkeyexpand

sim-controladd:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/ControlAdd.sv TOPLEVEL=ControlAdd COCOTB_TEST_MODULES=sim_controladd

sim-sboxlut:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/SboxLut.sv TOPLEVEL=SboxLut COCOTB_TEST_MODULES=sim_sbox

sim-sboxarish:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/SboxArish.sv TOPLEVEL=SboxArish COCOTB_TEST_MODULES=sim_sboxarish

sim-sboxcanright:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/SboxCanright.sv TOPLEVEL=SboxCanright COCOTB_TEST_MODULES=sim_sboxcanright

sim-%: FORCE
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

synth-sky:
	SKY130_PDK="$(SKY130_PDK)" bash syn/synth-sky130.sh $(SYN_TOP) $(SYN_SKY_OUT)

synth-sbox-area:
	bash syn/compare_sbox_area.sh

clean-synth:
	rm -rf $(SYN_OUT)
