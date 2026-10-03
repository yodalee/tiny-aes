
// AesCore.sv
//
// The module that instantiates the submodule and connect them together

module AesCore (
    input clk,
    input rst_n,
    // CSR
    input        r_dec,
    input [1:0]  r_level,
    input        r_start, // The one pulse start signal
    // Data input
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
logic [7:0] c_rc_idx, rc_data;
byte state_data;
byte key00, key20, key60, key70, key71;
byte subkey_data;
byte added_data;

assign c_keyexp = c_ke0 | c_ke1 | c_ke2;

ControlFsm i_control_fsm (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .r_level(r_level),
    .r_start(r_start),
    .i_valid(i_valid),
    .o_ready(o_ready),
    .i_ready(i_ready),
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
    .c_rc_idx(c_rc_idx),
    .c_add(c_add)
);

AesState i_aes_state (
    .clk(clk),
    .rst_n(rst_n),
    .c_srow0(c_srow0),
    .c_srow1(c_srow1),
    .c_srow2(c_srow2),
    .c_isrow0(c_isrow0),
    .c_isrow1(c_isrow1),
    .c_mixcol(c_mixcol),
    .i_state(c_add ? added_data : i_data),
    .o_state(state_data)
);

KeyExpansion i_key_expansion (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .r_level(r_level),
    .c_ke0(c_ke0),
    .c_ke1(c_ke1),
    .c_ke2(c_ke2),
    .c_kxor(c_kxor),
    .c_ikxor(c_ikxor),
    .i_key(i_data),
    .i_subkey(subkey_data),
    .i_rc(rc_data),
    .o_key00(key00),
    .o_key20(key20),
    .o_key60(key60),
    .o_key70(key70),
    .o_key71(key71)
);

RcLUT i_rc_lut (
    .i_data(c_rc_idx),
    .o_data(rc_data)
);

AddRoundKey i_add_round_key (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .c_add(c_add),
    .c_keyexp(c_keyexp),
    .i_key(c_ke2 ? key70 : key71),
    .i_state(state_data),
    .o_sbox(subkey_data),
    .o_added(added_data)
);

assign o_data = state_data;

endmodule