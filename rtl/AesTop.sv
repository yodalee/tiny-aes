
// AesTop.sv
//
// The module that instantiates the submodule and connect them together

module AesTop (
    input clk,
    input rst_n,
    // CSR
    input        r_dec,
    input [1:0]  r_level,
    /// Data input
    input        i_valid,
    output logic i_ready,
    input byte   i_data,
    // Data output
    output logic o_valid,
    input        o_ready,
    output byte  o_data
);

logic c_srow0, c_srow1, c_srow2;
logic c_isrow0, c_isrow1, c_mixcol;
logic c_ke0, c_ke1, c_ke2, c_kxor, c_ikxor;
logic c_add, c_keyexp;
logic [7:0] c_rc_idx;
byte core_data;

assign c_keyexp = c_ke0 | c_ke1 | c_ke2;

ControlFsm i_control_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .r_level(r_level),
    .i_valid(i_valid),
    .i_ready(i_ready),
    .o_ready(o_ready),
    .o_valid(o_valid),
    .c_srow0(c_srow0),
    .c_srow1(c_srow1),
    .c_srow2(c_srow2),
    .c_isrow0(c_isrow0),
    .c_isrow1(c_isrow1),
    .c_mixcol(c_mixcol),
    .c_ke0(c_ke0),
    .c_ke1(c_ke1),
    .c_ke2(c_ke2),
    .c_kxor(c_kxor),
    .c_ikxor(c_ikxor),
    .c_add(c_add),
    .c_rc_idx(c_rc_idx)
);

AesCore i_aes_core (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .r_level(r_level),
    .c_srow0(c_srow0),
    .c_srow1(c_srow1),
    .c_srow2(c_srow2),
    .c_isrow0(c_isrow0),
    .c_isrow1(c_isrow1),
    .c_mixcol(c_mixcol),
    .c_ke0(c_ke0),
    .c_ke1(c_ke1),
    .c_ke2(c_ke2),
    .c_kxor(c_kxor),
    .c_ikxor(c_ikxor),
    .c_add(c_add),
    .c_keyexp(c_keyexp),
    .c_rc_idx(c_rc_idx),
    .i_data(i_data),
    .o_data(o_data)
);

endmodule