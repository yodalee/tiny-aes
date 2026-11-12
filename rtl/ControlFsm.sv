// Centralized byte-streaming AES controller.  State timing follows
// doc/controlfsm.md; each processing state has a same-width microcode LUT.
module ControlFsm (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       r_dec,
    input  logic [1:0] r_level,
    // input/output signal
    input  logic       i_valid,
    output logic       i_ready,
    input  logic       o_ready,
    output logic       o_valid,
    output logic [4:0] d_state,
    // control signal
    output logic       c_stateen,
    output logic [2:0] c_srow,
    output logic       c_mixcol,
    output logic       c_loadkey,
    output logic       c_keyen,
    output logic       c_ke0,
    output logic       c_ke1,
    output logic       c_ke2,
    output logic       c_kxor,
    // Per-bypass enable mask: [4:0] = {key14, key24, key34, key64, key74}
    output logic [4:0] c_ikxor,
    // special control for decryption 192
    // [key20, key60]
    output logic [1:0] c_dec192_keysel,
    output logic       c_add,
    output logic       c_sbox
);

typedef enum logic [4:0] {
    kLoadData,
    kLoadKey,
    kE128Round,
    kE128Final,
    kD128Init,
    kD128Round,
    kD128Final,
    kE192Init,
    kE192Round1,
    kE192Round2,
    kE192Round3,
    kE192Round4,
    kE192Final,
    kD192Init,
    kD192Round1,
    kD192Round2,
    kD192Round3,
    kD192Final,
    kE256Init,
    kE256Round1,
    kE256Round3,
    kE256Round4,
    kE256Final,
    kD256Init,
    kD256Round1,
    kD256Round2,
    kD256Final,
    kOutput
} state_e;

typedef struct packed {
    logic c_stateen, c_mixcol;
    logic [2:0] c_srow;
    logic c_loadkey, c_keyen, c_ke0, c_ke1, c_ke2, c_kxor, c_add, c_sbox;
    logic [4:0] c_ikxor;
    logic [1:0] c_dec192_keysel;
} CtrlSignals_t;

// The LUT type is deliberately shared by all processing states.  These
// zero-filled tables are the specified microcode insertion points; the
// protocol and timing below do not depend on their contents.
localparam CtrlSignals_t kE128RoundLut  [0:22] = {
    '{c_srow: 3'b111,  c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE128FinalLut  [0:19] = {
    '{c_srow: 3'b111,  c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke1: 1'b1, default:'0},
    '{                c_ke1: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0}
};
localparam CtrlSignals_t kD128InitLut   [0:19] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, default:'0},
    '{c_srow: 3'b111,   c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b011,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b001,  c_ke1: 1'b1, default:'0},
    '{                 c_ke1: 1'b1, default:'0}
};
localparam CtrlSignals_t kD128RoundLut  [0:30] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b10011, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke0: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD128FinalLut  [0:15] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE192InitLut   [0:15] = {
    '{c_keyen: 1'b1, c_srow: 3'b111,  default:'0},
    '{c_keyen: 1'b1, c_srow: 3'b110,  default:'0},
    '{c_keyen: 1'b1, c_srow: 3'b100,  default:'0},
    '{c_keyen: 1'b1, c_mixcol: 1'b1, default:'0},
    '{c_keyen: 1'b1, c_mixcol: 1'b1, default:'0},
    '{c_keyen: 1'b1, c_mixcol: 1'b1, default:'0},
    '{c_keyen: 1'b1, c_mixcol: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0}
};
localparam CtrlSignals_t kE192R1Lut     [0:19] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_ke0: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE192R2Lut     [0:22] = {
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b110,  default:'0},
    '{c_srow: 3'b100,  default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}, // TODO: check this
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE192R3Lut     [0:22] = {
    '{c_srow: 3'b111,  c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE192R4Lut     [0:26] = {
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b110,  default:'0},
    '{c_srow: 3'b100,  default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor:  1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}, // TODO: Check the c_keyen
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_ke0: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE192FinalLut  [0:19] = {
    '{c_srow: 3'b111,  c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke1: 1'b1, default:'0},
    '{                c_ke1: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0}
};
localparam CtrlSignals_t kD192InitLut   [0:26] = {
    '{c_keyen: 1'b1, default:'0}, // Rotate key to first
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, default:'0},
    '{c_srow: 3'b111, default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD192R1Lut     [0:34] = {
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_ke0: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD192R2Lut     [0:30] = {
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11000, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11000, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11000, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_dec192_keysel: 2'b10, c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11000, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke0: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_srow: 3'b111, default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD192R3Lut     [0:30] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00110, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00110, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00110, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00110, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b00111, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD192FinalLut  [0:15] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE256InitLut   [0:19] = {
    '{c_ke0: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_ke1: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_kxor: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0}
};
localparam CtrlSignals_t kE256R1Lut     [0:22] = {
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b110,  default:'0},
    '{c_srow: 3'b100,  default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE256R3Lut     [0:22] = {
    '{c_srow: 3'b111,  c_ke2: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke2: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke2: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke2: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE256R4Lut     [0:22] = {
    '{c_srow: 3'b111,  c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_kxor: 1'b1, c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};
localparam CtrlSignals_t kE256FinalLut  [0:19] = {
    '{c_srow: 3'b111,  c_ke0: 1'b1, default:'0},
    '{c_srow: 3'b110,  c_ke1: 1'b1, default:'0},
    '{c_srow: 3'b100,  c_ke1: 1'b1, default:'0},
    '{                c_ke1: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_kxor: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0}
};
localparam CtrlSignals_t kD256InitLut   [0:34] = {
    '{c_keyen: 1'b1, default:'0}, // Rotate key to first
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, default:'0},
    '{c_srow: 3'b111,  default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD256R1Lut     [0:30] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke0: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke1: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_srow: 3'b111, default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD256R2Lut     [0:30] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_ikxor: 5'b11100, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke2: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke2: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke2: 1'b1, default:'0},
    '{c_mixcol: 1'b1, c_ke2: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_srow: 3'b111, default:'0},
    '{c_srow: 3'b011, default:'0},
    '{c_srow: 3'b001, default:'0}
};
localparam CtrlSignals_t kD256FinalLut  [0:15] = {
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0}
};

state_e state, state_n;
logic [5:0] cycle_q;
logic [3:0] round_q;
logic dec_q;
logic [1:0] level_q;
CtrlSignals_t ctrl;

function automatic logic [5:0] key_cycles(input logic [1:0] level);
    case (level)
        2'b00: key_cycles = 16;
        2'b01: key_cycles = 24;
        default: key_cycles = 32;
    endcase
endfunction

function automatic logic [5:0] cycles(input state_e s);
    case (s)
        kE192Init, kD128Final, kD192Final, kD256Final: cycles = 16;
        kE128Round, kE192Round2, kE192Round3, kE256Round1, kE256Round3, kE256Round4: cycles = 23;
        kE128Final, kD128Init, kE192Round1, kE192Final, kE256Init, kE256Final: cycles = 20;
        kD128Round, kD192Round2, kD192Round3, kD256Round1, kD256Round2: cycles = 31;
        kE192Round4, kD192Init: cycles = 27;
        kD192Round1, kD256Init: cycles = 35;
        default: cycles = 1;
    endcase
endfunction

function automatic logic is_round(input state_e s);
    case (s)
        kE128Round, kD128Round, kE192Round1, kE192Round2, kE192Round3, kE192Round4,
        kD192Round1, kD192Round2, kD192Round3, kE256Round1, kE256Round3, kE256Round4,
        kD256Round1, kD256Round2: is_round = 1'b1;
        default: is_round = 1'b0;
    endcase
endfunction

/* verilator lint_off WIDTHTRUNC */
function automatic CtrlSignals_t lut(input state_e s, input logic [5:0] i);
    CtrlSignals_t e128_init, e128_round, e128_final;
    CtrlSignals_t d128_init, d128_round, d128_final;
    CtrlSignals_t e192_init, e192_r1, e192_r2, e192_r3, e192_r4, e192_final;
    CtrlSignals_t d192_init, d192_r1, d192_r2, d192_r3, d192_final;
    CtrlSignals_t e256_init, e256_r1, e256_r3, e256_r4, e256_final;
    CtrlSignals_t d256_init, d256_r1, d256_r2, d256_final;
    begin
        // Evaluate every table before selecting one.  This also keeps the
        // synthesis compatibility lowering from making conditionally-called
        // function results into latches.
        e128_round = kE128RoundLut[i]; e128_final = kE128FinalLut[i];
        d128_init = kD128InitLut[i];   d128_round = kD128RoundLut[i]; d128_final = kD128FinalLut[i];
        e192_init = kE192InitLut[i];   e192_r1 = kE192R1Lut[i];       e192_r2 = kE192R2Lut[i];
        e192_r3 = kE192R3Lut[i];       e192_r4 = kE192R4Lut[i];       e192_final = kE192FinalLut[i];
        d192_init = kD192InitLut[i];   d192_r1 = kD192R1Lut[i];       d192_r2 = kD192R2Lut[i];
        d192_r3 = kD192R3Lut[i];       d192_final = kD192FinalLut[i];
        e256_init = kE256InitLut[i];   e256_r1 = kE256R1Lut[i];       e256_r3 = kE256R3Lut[i];
        e256_r4 = kE256R4Lut[i];       e256_final = kE256FinalLut[i];
        d256_init = kD256InitLut[i];   d256_r1 = kD256R1Lut[i];       d256_r2 = kD256R2Lut[i];
        d256_final = kD256FinalLut[i];
        lut = '0;
        case (s)
            kE128Round: lut = e128_round;
            kE128Final: lut = e128_final;
            kD128Init: lut = d128_init;
            kD128Round: lut = d128_round;
            kD128Final: lut = d128_final;
            kE192Init: lut = e192_init;
            kE192Round1: lut = e192_r1;
            kE192Round2: lut = e192_r2;
            kE192Round3: lut = e192_r3;
            kE192Round4: lut = e192_r4;
            kE192Final: lut = e192_final;
            kD192Init: lut = d192_init;
            kD192Round1: lut = d192_r1;
            kD192Round2: lut = d192_r2;
            kD192Round3: lut = d192_r3;
            kD192Final: lut = d192_final;
            kE256Init: lut = e256_init;
            kE256Round1: lut = e256_r1;
            kE256Round3: lut = e256_r3;
            kE256Round4: lut = e256_r4;
            kE256Final: lut = e256_final;
            kD256Init: lut = d256_init;
            kD256Round1: lut = d256_r1;
            kD256Round2: lut = d256_r2;
            kD256Final: lut = d256_final;
            default: ;
        endcase
    end
endfunction
/* verilator lint_on WIDTHTRUNC */

always_comb begin
    state_n = state;
    case (state)
        kLoadData: if (i_valid && cycle_q == 15) state_n = kLoadKey;
        kLoadKey: if (i_valid && cycle_q == key_cycles(level_q)-1)
            case ({dec_q, level_q})
                3'b000: state_n = kE128Round;
                3'b001: state_n = kE192Init;
                3'b010,3'b011: state_n = kE256Init;
                3'b100: state_n = kD128Init;
                3'b101: state_n = kD192Init;
                default: state_n = kD256Init;
            endcase
        kE128Round: if (round_q == 8) state_n = kE128Final;
        kE128Final: state_n = kOutput;
        kD128Init: state_n = kD128Round;
        kD128Round: if (round_q == 8) state_n = kD128Final;
        kD128Final: state_n = kOutput;
        kE192Init: state_n = kE192Round1;
        kE192Round1: state_n = kE192Round2;
        kE192Round2: state_n = round_q == 10 ? kE192Final : kE192Round3;
        kE192Round3: state_n = kE192Round4;
        kE192Round4: state_n = kE192Round2;
        kE192Final: state_n = kOutput;
        kD192Init: state_n = kD192Round1;
        kD192Round1: state_n = kD192Round2;
        kD192Round2: state_n = round_q == 10 ? kD192Final : kD192Round3;
        kD192Round3: state_n = kD192Round1;
        kD192Final: state_n = kOutput;
        kE256Init: state_n = kE256Round1;
        kE256Round1: if (round_q == 1) state_n = kE256Round3;
        kE256Round3: state_n = round_q == 12 ? kE256Final : kE256Round4;
        kE256Round4: state_n = kE256Round3;
        kE256Final: state_n = kOutput;
        kD256Init: state_n = kD256Round1;
        kD256Round1: state_n = round_q == 12 ? kD256Final : kD256Round2;
        kD256Round2: state_n = kD256Round1;
        kD256Final: state_n = kOutput;
        kOutput: if (o_ready && cycle_q == 15) state_n = kLoadData;
        default: state_n = kLoadData;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin state <= kLoadData;
        cycle_q <= '0;
        round_q <= '0;
        dec_q <= 0;
        level_q <= 0;
    end
    else if ((state == kLoadData || state == kLoadKey) && !i_valid) begin end
    else if (state == kOutput && !o_ready) begin end
    else begin
        if (state == kLoadData && cycle_q == 0) begin dec_q <= r_dec;
            level_q <= r_level;
        end
        if ((state == kLoadData && cycle_q == 15) || 
            (state == kLoadKey && cycle_q == key_cycles(level_q)-1) ||
            (state == kOutput && cycle_q == 15) ||
            ((state != kLoadData && state != kLoadKey && state != kOutput) && cycle_q == cycles(state)-1)) begin
            state <= state_n;
            cycle_q <= '0;
            if (is_round(state)) round_q <= round_q + 1'b1;
            else if (state == kLoadKey) round_q <= '0;
        end else cycle_q <= cycle_q + 1'b1;
    end
end

always_comb begin
    ctrl = lut(state, cycle_q);
    if (state == kLoadData) ctrl.c_stateen = i_valid;
    if (state == kLoadKey) begin
        ctrl.c_stateen = i_valid && cycle_q < 16;;
        ctrl.c_add = i_valid;
        ctrl.c_sbox = i_valid;
        ctrl.c_keyen = i_valid;
        ctrl.c_loadkey = i_valid;
    end
    if (state == kOutput) ctrl.c_stateen = o_ready;
end

assign i_ready = state == kLoadData || state == kLoadKey;
assign o_valid = state == kOutput;
assign d_state = state;

// control signal
assign c_stateen       = ctrl.c_stateen;
assign c_srow          = ctrl.c_srow;
assign c_mixcol        = ctrl.c_mixcol;
assign c_loadkey       = ctrl.c_loadkey;
assign c_keyen         = ctrl.c_keyen;
assign c_ke0           = ctrl.c_ke0;
assign c_ke1           = ctrl.c_ke1;
assign c_ke2           = ctrl.c_ke2;
assign c_kxor          = ctrl.c_kxor;
assign c_ikxor         = ctrl.c_ikxor;
assign c_add           = ctrl.c_add;
assign c_sbox          = ctrl.c_sbox;
assign c_dec192_keysel = ctrl.c_dec192_keysel;


endmodule
