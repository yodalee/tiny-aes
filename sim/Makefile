SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(abspath ../src/rtl/MixColumn.sv)
TOPLEVEL = MixColumn
COCOTB_TEST_MODULES = sim_mixcolumn
EXTRA_ARGS += -Wno-UNOPTFLAT

include $(shell cocotb-config --makefiles)/Makefile.sim
