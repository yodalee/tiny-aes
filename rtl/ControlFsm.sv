// Centralized byte-streaming AES controller.  State timing follows
// doc/controlfsm.md; each processing state has a same-width microcode LUT.
module ControlFsm (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       r_dec,
    input  logic [1:0] r_level,
    input  logic       i_valid,
    output logic       i_ready,
    input  logic       o_ready,
    output logic       o_valid,
    output logic       c_stateen,
    output logic       c_srow0,
    output logic       c_srow1,
    output logic       c_srow2,
    output logic       c_isrow0,
    output logic       c_isrow1,
    output logic       c_mixcol,
    output logic       c_loadkey,
    output logic       c_keyen,
    output logic       c_ke0,
    output logic       c_ke1,
    output logic       c_ke2,
    output logic       c_kxor,
    // Per-bypass enable mask: [5:0] = {key74, key64, key34, key24, key14, key04}.
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
    kE128Init,
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
    logic c_stateen, c_srow0, c_srow1, c_srow2, c_isrow0, c_isrow1, c_mixcol;
    logic c_loadkey, c_keyen, c_ke0, c_ke1, c_ke2, c_kxor, c_add, c_sbox;
    logic [4:0] c_ikxor;
    logic [1:0] c_dec192_keysel;
} CtrlSignals_t;

// The LUT type is deliberately shared by all processing states.  These
// zero-filled tables are the specified microcode insertion points; the
// protocol and timing below do not depend on their contents.
localparam CtrlSignals_t kE128InitLut   [0:15] = {
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
localparam CtrlSignals_t kE128RoundLut  [0:22] = {
    '{c_srow0: 1'b1,  c_ke0: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0: 1'b1,  c_ke0: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0: 1'b1,   c_ke0: 1'b1, default:'0},
    '{c_isrow0: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_isrow1: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0: 1'b1,  default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
localparam CtrlSignals_t kE192InitLut   [0:22] = {
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
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_srow0: 1'b1,  default:'0},
    '{c_srow1: 1'b1,  default:'0},
    '{c_srow2: 1'b1,  default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0},
    '{c_mixcol: 1'b1, default:'0}
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
    '{c_srow0: 1'b1,  default:'0},
    '{c_srow1: 1'b1,  default:'0},
    '{c_srow2: 1'b1,  default:'0},
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
    '{c_srow0: 1'b1,  c_ke0: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0: 1'b1,  default:'0},
    '{c_srow1: 1'b1,  default:'0},
    '{c_srow2: 1'b1,  default:'0},
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
    '{c_srow0: 1'b1,  c_ke0: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0:  1'b1, default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
    '{c_srow0:  1'b1,  default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
    '{c_srow0:  1'b1, default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
    '{c_srow0:  1'b1,  default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
localparam CtrlSignals_t kE256InitLut   [0:51] = {
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
    '{c_stateen: 1'b1, c_keyen: 1'b1, c_add: 1'b1, c_sbox: 1'b1, default:'0},
    '{c_keyen: 1'b1, default:'0}, // Move the dirty key to the front
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
    '{c_srow0: 1'b1,  default:'0},
    '{c_srow1: 1'b1,  default:'0},
    '{c_srow2: 1'b1,  default:'0},
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
    '{c_srow0: 1'b1,  c_ke2: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke2: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke2: 1'b1, default:'0},
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
    '{c_srow0: 1'b1,  c_ke0: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0: 1'b1,  c_ke0: 1'b1, default:'0},
    '{c_srow1: 1'b1,  c_ke1: 1'b1, default:'0},
    '{c_srow2: 1'b1,  c_ke1: 1'b1, default:'0},
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
    '{c_srow0:  1'b1,  default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
    '{c_srow0:  1'b1, default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
    '{c_srow0:  1'b1, default:'0},
    '{c_isrow0: 1'b1, default:'0},
    '{c_isrow1: 1'b1, default:'0}
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
        kE128Init, kD128Final, kD192Final, kD256Final: cycles = 16;
        kE128Round, kE192Round2, kE192Round3, kE256Round1, kE256Round3, kE256Round4, kE192Init: cycles = 23;
        kE128Final, kD128Init, kE192Round1, kE192Final, kE256Final: cycles = 20;
        kD128Round, kD192Round2, kD192Round3, kD256Round1, kD256Round2: cycles = 31;
        kE192Round4, kD192Init: cycles = 27;
        kD192Round1, kD256Init: cycles = 35;
        kE256Init: cycles = 52;
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
    begin
        lut = '0;
        case (s)
            kE128Init: lut = kE128InitLut[i];
            kE128Round: lut = kE128RoundLut[i];
            kE128Final: lut = kE128FinalLut[i];
            kD128Init: lut = kD128InitLut[i];
            kD128Round: lut = kD128RoundLut[i];
            kD128Final: lut = kD128FinalLut[i];
            kE192Init: lut = kE192InitLut[i];
            kE192Round1: lut = kE192R1Lut[i];
            kE192Round2: lut = kE192R2Lut[i];
            kE192Round3: lut = kE192R3Lut[i];
            kE192Round4: lut = kE192R4Lut[i];
            kE192Final: lut = kE192FinalLut[i];
            kD192Init: lut = kD192InitLut[i];
            kD192Round1: lut = kD192R1Lut[i];
            kD192Round2: lut = kD192R2Lut[i];
            kD192Round3: lut = kD192R3Lut[i];
            kD192Final: lut = kD192FinalLut[i];
            kE256Init: lut = kE256InitLut[i];
            kE256Round1: lut = kE256R1Lut[i];
            kE256Round3: lut = kE256R3Lut[i];
            kE256Round4: lut = kE256R4Lut[i];
            kE256Final: lut = kE256FinalLut[i];
            kD256Init: lut = kD256InitLut[i];
            kD256Round1: lut = kD256R1Lut[i];
            kD256Round2: lut = kD256R2Lut[i];
            kD256Final: lut = kD256FinalLut[i];
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
                3'b000: state_n = kE128Init;
                3'b001: state_n = kE192Init;
                3'b010,3'b011: state_n = kE256Init;
                3'b100: state_n = kD128Init;
                3'b101: state_n = kD192Init;
                default: state_n = kD256Init;
            endcase
        kE128Init: state_n = kE128Round;
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
        ctrl.c_keyen = i_valid;
        ctrl.c_loadkey = i_valid; end
    if (state == kOutput) ctrl.c_stateen = o_ready;
end

assign i_ready = state == kLoadData || state == kLoadKey;
assign o_valid = state == kOutput;

// control signal
assign c_stateen       = ctrl.c_stateen;
assign c_srow0         = ctrl.c_srow0;
assign c_srow1         = ctrl.c_srow1;
assign c_srow2         = ctrl.c_srow2;
assign c_isrow0        = ctrl.c_isrow0;
assign c_isrow1        = ctrl.c_isrow1;
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
