
// ControlFsm
//
// The centralized control state machine.

module ControlFsm (
	input  logic       clk,
	input  logic       rst_n,
    // CSR
	input  logic       r_dec,
	input  logic [1:0] r_level,
    // data input
	input  logic       i_valid,
	output logic       i_ready,
    // data output
	input  logic       o_ready,
	output logic       o_valid,
    // control signals of AesState
	output logic       c_stateen,
	output logic       c_srow0,
	output logic       c_srow1,
	output logic       c_srow2,
	output logic       c_isrow0,
	output logic       c_isrow1,
	output logic       c_mixcol,
    // control signals of KeyExpansion
    output logic       c_loadkey,
	output logic       c_keyen,
	output logic       c_ke0,
	output logic       c_ke1,
	output logic       c_ke2,
	output logic       c_kxor,
	output logic       c_ikxor,
    // Control signals of Sbox
	output logic       c_add,
    output logic       c_sbox,
    // Rc LUT
	output logic [7:0] c_rc_idx
);

logic mixcol_valid;
logic shiftrow_valid;

ControlMixColumn i_control_mixcolumn (
	.clk(clk),
	.rst_n(rst_n),
	.r_dec(r_dec),
	.i_valid(i_valid),
	.o_valid(mixcol_valid),
	.c_mixcol(c_mixcol)
);

ControlShiftrow i_control_shiftrow (
	.clk(clk),
	.rst_n(rst_n),
	.r_dec(r_dec),
	.i_valid(i_valid),
	.o_valid(shiftrow_valid),
	.c_srow0(c_srow0),
	.c_srow1(c_srow1),
	.c_srow2(c_srow2),
	.c_isrow0(c_isrow0),
	.c_isrow1(c_isrow1)
);

always_comb begin
	i_ready = 1'b1;
	o_valid = 1'b0;
	c_stateen = 1'b0;
	c_keyen = 1'b0;
	c_ke0 = 1'b0;
	c_ke1 = 1'b0;
	c_ke2 = 1'b0;
	c_kxor = 1'b0;
	c_ikxor = 1'b0;
	c_add = 1'b0;
	c_rc_idx = 8'b0;
end

endmodule
