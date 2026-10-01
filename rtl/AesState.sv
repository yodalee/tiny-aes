
module AesState (
    input       clk,
    input       rst_n,
    // control signal, prefix c_
    input       c_mixcol,
    // input and output byte
    input  byte i_state,
    output byte o_state
);

byte state00, state01, state02, state03;
byte state10, state11, state12, state13;
byte state20, state21, state22, state23;
byte state30, state31, state32, state33;

// The input wires of the state3x register
byte state40, state41, state42, state43;

int i_mixcol, o_mixcol;

// column 0
MuxEnableFF i_state00 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state01), .d1(state10), .q(state00)
);
MuxEnableFF i_state01 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state02), .d1(state11), .q(state01)
);
MuxEnableFF i_state02 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state03), .d1(state12), .q(state02)
);
MuxEnableFF i_state03 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state10), .d1(state13), .q(state03)
);

// column 1
MuxEnableFF i_state10 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state11), .d1(state20), .q(state10)
);
MuxEnableFF i_state11 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state12), .d1(state21), .q(state11)
);
MuxEnableFF i_state12 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state13), .d1(state22), .q(state12)
);
MuxEnableFF i_state13 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state20), .d1(state23), .q(state13)
);

// column 2
MuxEnableFF i_state20 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state21), .d1(state30), .q(state20)
);
MuxEnableFF i_state21 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state22), .d1(state31), .q(state21)
);
MuxEnableFF i_state22 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state23), .d1(state32), .q(state22)
);
MuxEnableFF i_state23 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state30), .d1(state33), .q(state23)
);

// column 3
MuxEnableFF i_state30 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state31), .d1(state40), .q(state30)
);
MuxEnableFF i_state31 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state32), .d1(state41), .q(state31)
);
MuxEnableFF i_state32 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(state33), .d1(state42), .q(state32)
);
MuxEnableFF i_state33 (
    .clk(clk), .rst_n(rst_n),
    .en(), .sel(c_mixcol),
    .d0(i_state), .d1(state43), .q(state33)
);

assign i_mixcol = {state00, state01, state02, state03};

// feedback wire or mix column
assign state40 = c_mixcol ? o_mixcol[24+:8] : state00;
assign state41 = c_mixcol ? o_mixcol[16+:8] : state01;
assign state42 = c_mixcol ? o_mixcol[ 8+:8] : state02;
assign state43 = c_mixcol ? o_mixcol[ 0+:8] : state03;

assign o_state = state00;

endmodule