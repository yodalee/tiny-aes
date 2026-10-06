
// AesUnit.sv
//
// The module that instantiates the submodule and connect them together

module AesCore (
    input clk,
    input rst_n,
    // CSR
    input        r_dec,
    input [1:0]  r_level,
    // Control signal from the controlfsm
    /// control of aes state
    input        c_srow0,
    input        c_srow1,
    input        c_srow2,
    input        c_isrow0,
    input        c_isrow1,
    input        c_mixcol,
    /// control of key expansion
    input        c_ke0,
    input        c_ke1,
    input        c_ke2,
    input        c_kxor,
    input        c_ikxor,
    /// control of sbox
    input        c_add,
    input        c_keyexp,
    /// rc_idx
    input byte   c_rc_idx,
    /// Data input
    input byte   i_data,
    // Data output
    output byte  o_data
);

byte state_data;
byte key00, key20, key60, key70, key71;
byte subkey_data;
byte added_data;
byte rc_data;

byte i_state;
assign i_state = c_add ? added_data : i_data;
AesState i_aes_state (
    .clk(clk),
    .rst_n(rst_n),
    .c_srow0(c_srow0),
    .c_srow1(c_srow1),
    .c_srow2(c_srow2),
    .c_isrow0(c_isrow0),
    .c_isrow1(c_isrow1),
    .c_mixcol(c_mixcol),
    .i_state(i_state),
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

byte i_key;
assign i_key = c_ke2 ? key70 : key71;
AddRoundKey i_add_round_key (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .c_add(c_add),
    .c_keyexp(c_keyexp),
    .i_key(i_key),
    .i_state(state_data),
    .o_sbox(subkey_data),
    .o_added(added_data)
);

assign o_data = state_data;

endmodule