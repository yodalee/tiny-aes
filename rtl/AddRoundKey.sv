
// AddRoundKey.sv
//
// Fully combinational module that connec the modules for
// AddRoundKey and Sbox/ISbox operations, and expose the control signals

// Control signal, not one-hot
// 1. c_add:  True if we are doing the add_round_key
//            This make the i_state xor with i_roundkey before or after sbox, depends on r_dec
// 2. c_sbox: True if we want the output of sbox
// 2. c_keyexpansion: True if we are doing the key expansion

module AddRoundKey (
    input  logic       clk,
    input  logic       rst_n,
    // register
    input              r_dec,
    // control signals, prefix with c_, should be one-hot
    input              c_add,
    input              c_sbox,
    input              c_keyexpansion,
    // input data
    input  byte        i_roundkey, // key for add round_key
    input  byte        i_state,    // state data for add round_key
    input  byte        i_sboxkey,  // key go to sbox for key expansion
    // output data
    output byte        o_key,
    output byte        o_state
);

// The state control
byte add_before, add_after;
assign add_before = (c_add && !r_dec) ? i_roundkey : 8'b0;
assign add_after =  (c_add && r_dec) ? i_roundkey : 8'b0;

// The key control
byte sbox_in, sbox_out;
assign sbox_in = (c_keyexpansion) ? i_sboxkey : i_state ^ add_before;

SboxLut i_sbox (
    .c_inv(r_dec),
    .i_data(sbox_in),
    .o_data(sbox_out)
);

// the output to key state (key expansion) always need the sbox
assign o_key = sbox_out;

assign o_state = (c_sbox) ? sbox_out ^ add_after : sbox_in;


endmodule
