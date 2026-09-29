SIM ?= verilator
TOPLEVEL_LANG ?= verilog
RTL_SOURCES ?= ../rtl/MixColumn.sv
TOPLEVEL ?= MixColumn
COCOTB_TEST_MODULES ?= sim_mixcolumn
SIM_BUILD ?= sim_build/$(TOPLEVEL)

VERILOG_SOURCES += $(abspath $(RTL_SOURCES))
EXTRA_ARGS += -Wno-UNOPTFLAT

include $(shell cocotb-config --makefiles)/Makefile.sim
