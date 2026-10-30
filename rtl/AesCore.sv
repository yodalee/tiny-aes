
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
    input        c_stateen,
    input        c_srow0,
    input        c_srow1,
    input        c_srow2,
    input        c_isrow0,
    input        c_isrow1,
    input        c_mixcol,
    /// control of key expansion
    input        c_loadkey,
    input        c_keyen,
    input        c_ke0,
    input        c_ke1,
    input        c_ke2,
    input        c_kxor,
    input        c_ikxor,
    input [1:0]  c_dec192_keysel,
    /// control of sbox
    input        c_add,
    input        c_sbox,
    input        c_keyexpansion,
    /// Data input
    input byte   i_data,
    // Data output
    output byte  o_data
);

byte state_data;
byte key00, key20, key60, key70, key71;
byte subkey_data;
byte added_data;

byte i_state;
assign i_state = c_add ? added_data : i_data;
AesState i_aes_state (
    .clk(clk),
    .rst_n(rst_n),
    .c_en(c_stateen),
    .c_srow0(c_srow0),
    .c_srow1(c_srow1),
    .c_srow2(c_srow2),
    .c_isrow0(c_isrow0),
    .c_isrow1(c_isrow1),
    .c_mixcol(c_mixcol),
    .i_state(i_state),
    .o_state(state_data)
);

byte i_roundkey;
always_comb begin : mux_roundkey
  i_roundkey = key00;
  if (c_loadkey) begin
    i_roundkey = i_data;
  end
  else if (c_dec192_keysel[1]) begin
    i_roundkey = key20;
  end else if (c_dec192_keysel[0]) begin
    i_roundkey = key60;
  end
end

KeyExpansion i_key_expansion (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .r_level(r_level),
    .c_en(c_keyen),
    .c_loadkey(c_loadkey),
    .c_ke0(c_ke0),
    .c_ke1(c_ke1),
    .c_ke2(c_ke2),
    .c_kxor(c_kxor),
    .c_ikxor(c_ikxor),
    .i_key(i_roundkey),
    .i_subkey(subkey_data),
    .o_key00(key00),
    .o_key20(key20),
    .o_key60(key60),
    .o_key70(key70),
    .o_key71(key71)
);

byte i_sboxkey;
assign i_sboxkey = c_ke2 ? key70 : key71;
AddRoundKey i_add_round_key (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec),
    .c_add(c_add),
    .c_sbox(c_sbox),
    .c_keyexpansion(c_keyexpansion),
    .i_roundkey(i_roundkey),
    .i_state(state_data),
    .i_sboxkey(i_sboxkey),
    .o_key(subkey_data),
    .o_state(added_data)
);

assign o_data = state_data;

endmodule
