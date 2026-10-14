SIM ?= verilator
TOPLEVEL_LANG ?= verilog
RTL_SOURCES ?= ../rtl/MixColumn.sv
TOPLEVEL ?= MixColumn
COCOTB_TEST_MODULES ?= sim_mixcolumn
SIM_BUILD ?= sim_build/$(TOPLEVEL)

VERILOG_SOURCES += $(abspath $(RTL_SOURCES))
EXTRA_ARGS += -Wno-UNOPTFLAT

# The top-level AES test enables this switch so its traces are compact FST
# files suitable for GTKWave.  Other unit-level simulations stay untraced.
ifeq ($(AESTOP_TRACE),1)
EXTRA_ARGS += --trace-fst --trace-structs
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
