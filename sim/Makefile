SIM ?= verilator
TOPLEVEL_LANG ?= verilog
RTL_SOURCES ?= ../rtl/MixColumn.sv
TOPLEVEL ?= MixColumn
COCOTB_TEST_MODULES ?= sim_mixcolumn
SIM_BUILD ?= sim_build/$(TOPLEVEL)

VERILOG_SOURCES += $(abspath $(RTL_SOURCES))

ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wno-UNOPTFLAT

# Set WAVES=1 on Verilator simulations to write a compact FST trace suitable
# for GTKWave.
ifeq ($(WAVES),1)
EXTRA_ARGS += --trace --trace-fst --trace-structs
EXTRA_ARGS += -DDEBUG
endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
