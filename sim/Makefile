SIM ?= verilator
TOPLEVEL_LANG ?= verilog
RTL_SOURCES ?= ../rtl/MixColumn.sv
TOPLEVEL ?= MixColumn
COCOTB_TEST_MODULES ?= sim_mixcolumn
SIM_BUILD ?= sim_build/$(TOPLEVEL)

VERILOG_SOURCES += $(abspath $(RTL_SOURCES))
EXTRA_ARGS += -Wno-UNOPTFLAT

# Set DUMP=1 on any simulation target to write a compact FST trace suitable
# for GTKWave.
ifeq ($(DUMP),1)
EXTRA_ARGS += --trace --trace-fst --trace-structs
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
