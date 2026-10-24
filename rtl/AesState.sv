
// AesState
//
// Module to hold the 4x4 AES state matrix and perform byte-serial state
// movement. The matrix is implemented as a shift-register network so the same
// storage can support load, output, ShiftRows, InvShiftRows, and MixColumns.
// The output byte is always state00.
//
// There are 6 main control operations:
// 1. c_en:
//    Global byte shift enable. When no row/mix operation is selected, each
//    enabled register shifts through the serial state path and i_state enters
//    at state33.
// 2. c_srow0:
//    First ShiftRows step. Rotates rows 1, 2, and 3 left by one byte.
// 3. c_srow1:
//    Second ShiftRows step. Rotates rows 2 and 3 left by one byte.
// 4. c_srow2:
//    Third ShiftRows step. Rotates row 3 left by one byte.
// 5. c_isrow0
//    InvShiftRows steps. Rotates rows rows 1.
// 6. c_isrow1:
//    InvShiftRows steps. Rotates rows rows 1 and 2.
//    A inverse shift row can be doen by c_srow0, c_isrow0 and c_isrow1
// 6. c_mixcol:
//    Mixes the current first column, feeds the result through the phantom
//    state4x wires, and shifts the mixed column back into the matrix.
//    Forward MixColumn is c_mixcol by 4 cycles.
//    Inverse MixColumn is c_mixcol by 12 cycles.
//
// The row controls and c_mixcol select the row/mix feedback path. These
// controls should be one-hot so only one state permutation is requested in a
// cycle.

module AesState (
    input       clk,
    input       rst_n,
    // Global state shift enable
    input       c_en,
    // Row/mix controls below are one-hot
    // Rotate rows 1,2,3 left
    input       c_srow0,
    // Rotate rows 2,3 left
    input       c_srow1,
    // Rotate rows 3 left
    input       c_srow2,
    // Rotate rows 1 left
    input       c_isrow0,
    // Rotate rows 1,2 left
    input       c_isrow1,
    // mix column for 1 cycle
    input       c_mixcol,
    // input and output byte
    input  byte i_state,
    output byte o_state
);

byte state00, state01, state02, state03;
byte state10, state11, state12, state13;
byte state20, state21, state22, state23;
byte state30, state31, state32, state33;
// The phantom input of column 3
byte state40, state41, state42, state43;

// Per-row enables. Row operations only enable the rows that need to move.
logic enrow0, enrow1, enrow2, enrow3;
assign enrow0 = c_en | c_mixcol;
assign enrow1 = c_en | c_mixcol | c_srow0 | c_isrow0 | c_isrow1;
assign enrow2 = c_en | c_mixcol | c_srow0 | c_srow1  | c_isrow1;
assign enrow3 = c_en | c_mixcol | c_srow0 | c_srow1  | c_srow2 ;

// Selects serial shift input or row/mix feedback input for the state flops.
logic sel_row;
assign sel_row = c_srow0 | c_srow1 | c_srow2 | c_isrow0 | c_isrow1 | c_mixcol;

// column 0
MuxEnableFF i_state00 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow0), .sel(sel_row),
    .d0(state01), .d1(state10), .q(state00)
);
MuxEnableFF i_state01 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow1), .sel(sel_row),
    .d0(state02), .d1(state11), .q(state01)
);
MuxEnableFF i_state02 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow2), .sel(sel_row),
    .d0(state03), .d1(state12), .q(state02)
);
MuxEnableFF i_state03 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow3), .sel(sel_row),
    .d0(state10), .d1(state13), .q(state03)
);

// column 1
MuxEnableFF i_state10 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow0), .sel(sel_row),
    .d0(state11), .d1(state20), .q(state10)
);
MuxEnableFF i_state11 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow1), .sel(sel_row),
    .d0(state12), .d1(state21), .q(state11)
);
MuxEnableFF i_state12 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow2), .sel(sel_row),
    .d0(state13), .d1(state22), .q(state12)
);
MuxEnableFF i_state13 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow3), .sel(sel_row),
    .d0(state20), .d1(state23), .q(state13)
);

// column 2
MuxEnableFF i_state20 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow0), .sel(sel_row),
    .d0(state21), .d1(state30), .q(state20)
);
MuxEnableFF i_state21 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow1), .sel(sel_row),
    .d0(state22), .d1(state31), .q(state21)
);
MuxEnableFF i_state22 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow2), .sel(sel_row),
    .d0(state23), .d1(state32), .q(state22)
);
MuxEnableFF i_state23 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow3), .sel(sel_row),
    .d0(state30), .d1(state33), .q(state23)
);

// column 3
MuxEnableFF i_state30 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow0), .sel(sel_row),
    .d0(state31), .d1(state40), .q(state30)
);
MuxEnableFF i_state31 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow1), .sel(sel_row),
    .d0(state32), .d1(state41), .q(state31)
);
MuxEnableFF i_state32 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow2), .sel(sel_row),
    .d0(state33), .d1(state42), .q(state32)
);
MuxEnableFF i_state33 (
    .clk(clk), .rst_n(rst_n),
    .en(enrow3), .sel(sel_row),
    .d0(i_state), .d1(state43), .q(state33)
);

// Mix column instance and wiring
int i_mixcol, o_mixcol;
MixColumn i_mixcolumn( .i_data(i_mixcol), .o_data(o_mixcol) );
assign i_mixcol = {state03, state02, state01, state00};

// Feedback path for the fourth column. During MixColumns it carries the mixed
// first column; otherwise it wraps the first column around for row movement.
assign state40 = c_mixcol ? o_mixcol[ 0+:8] : state00;
assign state41 = c_mixcol ? o_mixcol[ 8+:8] : state01;
assign state42 = c_mixcol ? o_mixcol[16+:8] : state02;
assign state43 = c_mixcol ? o_mixcol[24+:8] : state03;

assign o_state = state00;

byte debug_state [16];
assign debug_state = {
    state00, state01, state02, state03,
    state10, state11, state12, state13,
    state20, state21, state22, state23,
    state30, state31, state32, state33
};

endmodule
