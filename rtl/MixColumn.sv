
// MixColumn
// Fully combinational circuit of Rijndael MixColumns function.
// Based on the result of: https://eprint.iacr.org/2026/1481.pdf

module MixColumn (
    input  logic [31:0] i_data,
    output logic [31:0] o_data
);

logic [55:0] t;
logic [31:0] y;

assign t[0]  = i_data[7] ^ i_data[23];
assign t[1]  = i_data[15] ^ i_data[23];
assign t[2]  = i_data[7] ^ i_data[31];
assign t[3]  = i_data[0] ^ t[1];
assign t[4]  = i_data[16] ^ i_data[24];
assign t[5]  = t[4] ^ t[0];
assign y[8]  = t[4] ^ t[3];
assign t[6]  = i_data[8] ^ t[5];
assign t[7]  = t[6] ^ y[8];
assign y[0]  = t[6] ^ t[1];
assign t[8]  = i_data[16] ^ t[2];
assign t[9]  = y[0] ^ t[8];
assign y[16] = t[3] ^ t[9];
assign y[24] = t[5] ^ y[16];
assign t[10] = i_data[1] ^ i_data[9];
assign t[11] = i_data[9] ^ i_data[17];
assign t[12] = i_data[25] ^ t[10];
assign t[13] = i_data[17] ^ t[12];
assign t[14] = t[5] ^ t[2];
assign y[17] = t[12] ^ t[14];
assign t[15] = i_data[1] ^ t[7];
assign y[1]  = t[13] ^ t[15];
assign t[16] = t[9] ^ t[11];
assign y[9]  = t[16] ^ y[17];
assign y[25] = t[15] ^ t[16];
assign t[17] = i_data[2] ^ i_data[10];
assign t[18] = i_data[10] ^ i_data[18];
assign t[19] = t[13] ^ t[17];
assign t[20] = i_data[18] ^ t[11];
assign t[21] = i_data[26] ^ t[10];
assign t[22] = i_data[2] ^ i_data[26];
assign t[23] = t[17] ^ t[0];
assign y[2]  = t[18] ^ t[21];
assign y[10] = t[20] ^ t[22];
assign y[18] = t[19] ^ t[21];
assign y[26] = t[19] ^ t[20];
assign t[24] = i_data[19] ^ t[1];
assign t[25] = i_data[11] ^ t[22];
assign t[26] = i_data[3] ^ i_data[27];
assign t[27] = i_data[11] ^ t[24];
assign t[28] = i_data[3] ^ i_data[19];
assign t[29] = t[18] ^ t[26];
assign t[30] = t[2] ^ t[25];
assign t[31] = t[23] ^ t[27];
assign y[3]  = i_data[27] ^ t[31];
assign y[11] = t[24] ^ t[29];
assign t[32] = t[29] ^ t[30];
assign y[19] = t[23] ^ t[32];
assign y[27] = t[28] ^ t[30];
assign t[33] = i_data[12] ^ i_data[28];
assign t[34] = i_data[20] ^ t[27];
assign t[35] = t[28] ^ t[0];
assign t[36] = i_data[12] ^ i_data[20];
assign t[37] = t[33] ^ t[35];
assign t[38] = i_data[4] ^ t[2];
assign t[39] = i_data[4] ^ i_data[28];
assign t[40] = t[26] ^ t[38];
assign y[4]  = t[34] ^ t[37];
assign y[12] = t[39] ^ t[34];
assign y[20] = t[37] ^ t[40];
assign y[28] = t[36] ^ t[40];
assign t[41] = i_data[13] ^ i_data[29];
assign t[42] = i_data[21] ^ t[39];
assign t[43] = i_data[21] ^ i_data[29];
assign t[44] = i_data[5] ^ t[36];
assign t[45] = t[33] ^ t[41];
assign t[46] = i_data[5] ^ i_data[13];
assign y[5]  = t[42] ^ t[45];
assign y[13] = t[43] ^ t[44];
assign y[21] = t[44] ^ t[45];
assign y[29] = t[42] ^ t[46];
assign t[47] = i_data[6] ^ i_data[22];
assign t[48] = t[41] ^ t[47];
assign t[49] = i_data[14] ^ t[46];
assign t[50] = i_data[22] ^ i_data[30];
assign t[51] = i_data[30] ^ t[43];
assign t[52] = i_data[6] ^ i_data[14];
assign y[6]  = t[49] ^ t[50];
assign y[14] = t[48] ^ t[51];
assign y[22] = t[51] ^ t[52];
assign y[30] = t[48] ^ t[49];
assign t[53] = i_data[15] ^ t[50];
assign t[54] = i_data[31] ^ t[52];
assign t[55] = t[47] ^ t[0];
assign y[7]  = t[1] ^ t[54];
assign y[15] = t[54] ^ t[55];
assign y[23] = t[53] ^ t[2];
assign y[31] = t[53] ^ t[55];

assign o_data = y;

endmodule
