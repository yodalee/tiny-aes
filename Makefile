SIM ?= verilator
TEST ?= mixcolumn
SYN_TOP ?= AesTop
SYN_OUT ?= build/syn

.PHONY: help sim sim-mixcolumn sim-sbox sim-% sim-all clean-sim

help:
	@printf 'Targets:\n'
	@printf '  make sim              Run the default simulation (mixcolumn)\n'
	@printf '  make sim TEST=<name>  Run sim/sim_<name>.py\n'
	@printf '  make sim-<name>       Run sim/sim_<name>.py\n'
	@printf '  make sim-all          Run all sim/sim_*.py tests\n'
	@printf '  make synth            Synthesize RTL with Yosys (SYN_TOP=AesTop)\n'
	@printf '  make clean-sim        Remove simulation build outputs\n'
	@printf '  make clean-synth      Remove synthesis build outputs\n'

sim: sim-$(TEST)

sim-mixcolumn:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/MixColumn.sv TOPLEVEL=MixColumn COCOTB_TEST_MODULES=sim_mixcolumn

sim-sbox:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES=../rtl/Sbox.sv TOPLEVEL=Sbox COCOTB_TEST_MODULES=sim_sbox

sim-%:
	$(MAKE) -C sim SIM=$(SIM) RTL_SOURCES='$(RTL_SOURCES)' TOPLEVEL='$(TOPLEVEL)' COCOTB_TEST_MODULES=sim_$*

sim-all:
	@set -e; \
	for test in sim/sim_*.py; do \
		name=$${test#sim/sim_}; \
		name=$${name%.py}; \
		$(MAKE) sim-$$name SIM=$(SIM); \
	done

clean-sim:
	$(MAKE) -C sim clean

synth:
	bash syn/synth.sh $(SYN_TOP) $(SYN_OUT)

clean-synth:
	rm -rf $(SYN_OUT)
