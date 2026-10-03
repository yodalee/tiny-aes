
// AddRoundKey.sv
//
// Fully combinational module that connec the modules for
// AddRoundKey and Sbox/ISbox operations, and expose the control signals

module AddRoundKey (
    input  logic       clk,
    input  logic       rst_n,
    // register
    input              r_dec,
    // control signals, prefix with c_, should be one-hot
    input              c_add,
    input              c_keyexp,
    // input data
    input  byte        i_key,
    input  byte        i_state,
    // output data
    output byte        o_sbox,
    output byte        o_added
);

// The state control
byte add_before, add_after;
assign add_before = (c_add && !r_dec) ? i_key : 8'b0;
assign add_after =  (c_add && r_dec) ? i_key : 8'b0;

// The key control
byte sbox_in, sbox_out;
assign sbox_in = (c_keyexp) ? i_key : i_state ^ add_before; 

Sbox i_sbox (
    .c_inv(r_dec),
    .i_data(sbox_in),
    .o_data(sbox_out)
);

assign o_sbox = sbox_out;
assign o_added = sbox_out ^ add_after;


endmodule
