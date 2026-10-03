
// ControlFsm
//
// The centralized control state machine.

module ControlFsm (
	input  logic       clk,
	input  logic       rst_n,
    // CSR
	input  logic       r_dec,
	input  logic [1:0] r_level,
    input  logic       r_start, // The one pulse start signal
    // data input
	input  logic       i_valid,
	output logic       i_ready,
    // data output
	input  logic       o_ready,
	output logic       o_valid,
    // control signals of AesState
	output logic       c_srow0,
	output logic       c_srow1,
	output logic       c_srow2,
	output logic       c_isrow0,
	output logic       c_isrow1,
	output logic       c_mixcol,
    // control signals of KeyExpansion
	output logic       c_ke0,
	output logic       c_ke1,
	output logic       c_ke2,
	output logic       c_kxor,
	output logic       c_ikxor,
    // Rc LUT
	output logic [7:0] c_rc_idx
);

always_comb begin
	i_ready = 1'b1;
	o_valid = 1'b0;
	c_srow0 = 1'b0;
	c_srow1 = 1'b0;
	c_srow2 = 1'b0;
	c_isrow0 = 1'b0;
	c_isrow1 = 1'b0;
	c_mixcol = 1'b0;
	c_ke0 = 1'b0;
	c_ke1 = 1'b0;
	c_ke2 = 1'b0;
	c_kxor = 1'b0;
	c_ikxor = 1'b0;
	c_rc_idx = 8'b0;
end

endmodule
