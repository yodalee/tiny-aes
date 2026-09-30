
// KeyExpansion
//
// Module to hold all the key state and do the Rijndael key schedule
// There are 5 main operations:
// 1. ke0: Key Expansion type 0: Sbox(key71) xor RC xor key00
//         Example usage k16 <- k00 xor S(k13) xor RC
// 2. ke1: Key Expansion type 1: Sbox(key71) xor key00
//         Example usage k17 <- k01 xor S(k14)
// 3. ke2: Key Expansion type 2: Sbox(key70) xor key00
//         Example usage k48 <- k16 xor S(k44), Only used in AES256.c_ke0
//         Note that first row will be k16, k20, k24, k28, k32, k36, k40, k44
// 4. kxor:
// 5. ikxor
//         general use, (16-4), (24-4), (32-8) kxor operation in AES128, 192, 256
//         Example usage k20 <- k4 xor k16

import AesPkg::kLevel128;
import AesPkg::kLevel192;

module KeyExpansion (
    input       clk,
    input       rst_n,
    // register signal,
    input       r_dec,
    input [1:0] r_level,
    // control signal, prefix with c_, should be one-hot
    input       c_ke0,
    input       c_ke1,
    input       c_ke2,
    input       c_kxor,
    input       c_ikxor,
    // general input of key data, from outside or key00, 20, 60
    input  byte i_key,
    input  byte i_subkey, // key byte goes through sbox/isbox
    input  byte i_rc,
    // output from the register data
    output byte o_key00,
    output byte o_key20,
    output byte o_key60,
    output byte o_key70,
    output byte o_key71
);

// wire derived from c_ signal
// en: the key expansion pipeline is active
logic en;
assign en = c_ke0 | c_ke1 | c_ke2 | c_kxor | c_ikxor;
// True if we need to XOR the RC, only ke0 operation need it
logic mux_RC;
assign mux_RC = c_ke0;
// mux 4: True if the key update need Sbox
logic mux_Sbox;
assign mux_Sbox = c_ke0 | c_ke1 | c_ke2;
// mux 5: skip control for 128
logic mux_skip128;
assign mux_skip128 = r_level == kLevel128;
// mux 6: skip control for 182
logic mux_skip192;
assign mux_skip192 = r_level == kLevel192;
// mux12: input control
logic [1:0] mux_input;
// Select signal for key03
logic sel03;

// wires for register output
byte key00, key01, key02, key03;
byte key10, key11, key12, key13;
byte key20, key21, key22, key23;
byte key30, key31, key32, key33;
byte key40, key41, key42, key43;
byte key50, key51, key52, key53;
byte key60, key61, key62, key63;
byte key70, key71, key72, key73;

// phantom signal for input signal from special path
byte key04, key14, key24, key34, key64, key74;

// column 0
EnableFF    i_key00 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key01), .q(key00) );
EnableFF    i_key01 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key02), .q(key01) );
EnableFF    i_key02 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key03), .q(key02) );
MuxEnableFF i_key03 (
    .clk(clk), .rst_n(rst_n),
    .en(en), .sel(sel03),
    .d0(key10), .d1(key04), .q(key03)
);

// column 1
EnableFF    i_key10 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key11), .q(key10) );
EnableFF    i_key11 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key12), .q(key11) );
EnableFF    i_key12 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key13), .q(key12) );
EnableFF    i_key13 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key14), .q(key13) );

// column 2
EnableFF    i_key20 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key21), .q(key20) );
EnableFF    i_key21 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key22), .q(key21) );
EnableFF    i_key22 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key23), .q(key22) );
EnableFF    i_key23 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key24), .q(key23) );

// column 3
EnableFF    i_key30 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key31), .q(key30) );
EnableFF    i_key31 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key32), .q(key31) );
EnableFF    i_key32 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key33), .q(key32) );
EnableFF    i_key33 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key34), .q(key33) );

// column 4
EnableFF    i_key40 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key41), .q(key40) );
EnableFF    i_key41 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key42), .q(key41) );
EnableFF    i_key42 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key43), .q(key42) );
EnableFF    i_key43 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key50), .q(key43) );

// column 5
EnableFF    i_key50 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key51), .q(key50) );
EnableFF    i_key51 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key52), .q(key51) );
EnableFF    i_key52 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key53), .q(key52) );
EnableFF    i_key53 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key60), .q(key53) );

// column 6
EnableFF    i_key60 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key61), .q(key60) );
EnableFF    i_key61 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key62), .q(key61) );
EnableFF    i_key62 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key63), .q(key62) );
EnableFF    i_key63 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key64), .q(key63) );

// column 7
EnableFF    i_key70 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key71), .q(key70) );
EnableFF    i_key71 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key72), .q(key71) );
EnableFF    i_key72 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key73), .q(key72) );
EnableFF    i_key73 ( .clk(clk), .rst_n(rst_n), .en(en), .d(key74), .q(key73) );

// The key update path
byte rc;
assign rc = mux_RC ? i_rc : 8'b0;
byte subkey;
assign subkey = i_subkey ^ rc;
assign key04 = key00 ^ ((mux_Sbox)? subkey : key10);

// The select input for decrypt and level
// TODO: key14, 24, 34, 64, 74 need to deal with sel1, 2, 3, 6, 7 for decryption
assign key14 = mux_skip128 ? key60 : key20;
assign key24 = key30;
assign key34 = mux_skip192 ? key60 : key40;
assign key64 = key70;

always_comb begin : comb_key74
if (mux_input == 2'b01) begin
    key74 = key70;
end else if (mux_input == 2'b10) begin
    key74 = key00;
end else begin
    key74 = i_key;
end
end

// output port
assign o_key00 = key00;
assign o_key20 = key20;
assign o_key60 = key60;
assign o_key70 = key70;
assign o_key71 = key71;


endmodule