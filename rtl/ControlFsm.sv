// ControlFsm
//
// The centralized control state machine.

import AesPkg::kLevel128;
import AesPkg::kLevel192;
import AesPkg::kLevel256;

module ControlFsm (
	input  logic       clk,
	input  logic       rst_n,
    // CSR
	input  logic       r_dec,
	input  logic [1:0] r_level,
    // data input
	input  logic       i_valid,
	output logic       i_ready,
    // data output
	input  logic       o_ready,
	output logic       o_valid,
    // control signals of AesState
	output logic       c_en,
	output logic       c_srow0,
	output logic       c_srow1,
	output logic       c_srow2,
	output logic       c_isrow0,
	output logic       c_isrow1,
	output logic       c_mixcol,
    // control signals of KeyExpansion
	output logic       c_ke0,
	output logic       c_ke1,
	output logic       c_ke2,
	output logic       c_kxor,
	output logic       c_ikxor,
    // Control signals of Sbox
	output logic       c_add,
    output logic       c_sbox,
    // Rc LUT
	output logic [7:0] c_rc_idx
);

typedef enum logic [2:0] {
    kCtrlLoadData,
    kCtrlLoadKey,
    kCtrlLoadExtraKey,
    kCtrlInit,
    kCtrlRoundAes128Enc,
    kCtrlRoundAes128Dec,
    kCtrlFinalize,
    kCtrlOutput
} CtrlState_e;

typedef struct packed {
    logic c_en;
    logic c_srow0;
    logic c_srow1;
    logic c_srow2;
    logic c_isrow0;
    logic c_isrow1;
    logic c_mixcol;
    logic c_ke0;
    logic c_ke1;
    logic c_ke2;
    logic c_kxor;
    logic c_ikxor;
    logic c_add;
    logic c_sbox;
} CtrlSignals_t;

localparam logic [5:0] kLoadDataCycles      = 6'd16;
localparam logic [5:0] kLoadKeyCycles       = 6'd16;
localparam logic [5:0] kInitCycles          = 6'd16;
localparam logic [5:0] kAes128EncRoundCycles = 6'd23;
localparam logic [5:0] kAes128DecRoundCycles = 6'd31;
localparam logic [5:0] kFinalizeCycles      = 6'd19;
localparam logic [5:0] kOutputCycles        = 6'd16;
localparam logic [3:0] kAes128Rounds        = 4'd10;

CtrlState_e state_q;
logic [5:0] cycle_q;
logic [3:0] round_q;

function automatic CtrlSignals_t ctrl_zero();
    CtrlSignals_t ctrl;
    ctrl = '0;
    return ctrl;
endfunction

function automatic logic [5:0] extra_key_cycles(input logic [1:0] level);
    unique case (level)
        kLevel192: extra_key_cycles = 6'd8;
        kLevel256: extra_key_cycles = 6'd16;
        default:   extra_key_cycles = 6'd0;
    endcase
endfunction

function automatic logic [5:0] state_cycles(
    input CtrlState_e state,
    input logic [1:0] level
);
    unique case (state)
        kCtrlLoadData:       state_cycles = kLoadDataCycles;
        kCtrlLoadKey:        state_cycles = kLoadKeyCycles;
        kCtrlLoadExtraKey:   state_cycles = extra_key_cycles(level);
        kCtrlInit:           state_cycles = kInitCycles;
        kCtrlRoundAes128Enc: state_cycles = kAes128EncRoundCycles;
        kCtrlRoundAes128Dec: state_cycles = kAes128DecRoundCycles;
        kCtrlFinalize:       state_cycles = kFinalizeCycles;
        default:             state_cycles = kOutputCycles;
    endcase
endfunction

function automatic CtrlSignals_t load_data_lut(input logic [5:0] idx);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: ctrl.c_en = 1'b1;
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t load_key_lut(input logic [5:0] idx);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: ctrl.c_kxor = 1'b1;
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t load_extra_key_lut(input logic [5:0] idx);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: ctrl.c_kxor = 1'b1;
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t init_lut(input logic [5:0] idx);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: begin
            ctrl.c_en  = 1'b1;
            ctrl.c_add = 1'b1;
        end
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t aes128_enc_round_lut(input logic [5:0] idx);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: begin
            ctrl.c_en   = 1'b1;
            ctrl.c_add  = 1'b1;
            ctrl.c_sbox = 1'b1;
        end
        6'd16: ctrl.c_srow0  = 1'b1;
        6'd17: ctrl.c_srow1  = 1'b1;
        6'd18: ctrl.c_srow2  = 1'b1;
        6'd19, 6'd20, 6'd21, 6'd22: ctrl.c_mixcol = 1'b1;
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t aes128_dec_round_lut(input logic [5:0] idx);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: begin
            ctrl.c_en   = 1'b1;
            ctrl.c_add  = 1'b1;
            ctrl.c_sbox = 1'b1;
        end
        6'd16: ctrl.c_srow0  = 1'b1;
        6'd17: ctrl.c_isrow0 = 1'b1;
        6'd18: ctrl.c_isrow1 = 1'b1;
        6'd19, 6'd20, 6'd21, 6'd22,
        6'd23, 6'd24, 6'd25, 6'd26,
        6'd27, 6'd28, 6'd29, 6'd30: ctrl.c_mixcol = 1'b1;
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t finalize_lut(
    input logic [5:0] idx,
    input logic dec
);
    CtrlSignals_t ctrl;
    ctrl = ctrl_zero();
    unique case (idx)
        6'd0,  6'd1,  6'd2,  6'd3,
        6'd4,  6'd5,  6'd6,  6'd7,
        6'd8,  6'd9,  6'd10, 6'd11,
        6'd12, 6'd13, 6'd14, 6'd15: begin
            ctrl.c_en   = 1'b1;
            ctrl.c_add  = 1'b1;
            ctrl.c_sbox = 1'b1;
        end
        6'd16: ctrl.c_srow0 = 1'b1;
        6'd17: begin
            ctrl.c_srow1  = !dec;
            ctrl.c_isrow0 = dec;
        end
        6'd18: begin
            ctrl.c_srow2  = !dec;
            ctrl.c_isrow1 = dec;
        end
        default: begin
        end
    endcase
    return ctrl;
endfunction

function automatic CtrlSignals_t control_lut(
    input CtrlState_e state,
    input logic [5:0] idx,
    input logic dec
);
    unique case (state)
        kCtrlLoadData:       control_lut = load_data_lut(idx);
        kCtrlLoadKey:        control_lut = load_key_lut(idx);
        kCtrlLoadExtraKey:   control_lut = load_extra_key_lut(idx);
        kCtrlInit:           control_lut = init_lut(idx);
        kCtrlRoundAes128Enc: control_lut = aes128_enc_round_lut(idx);
        kCtrlRoundAes128Dec: control_lut = aes128_dec_round_lut(idx);
        kCtrlFinalize:       control_lut = finalize_lut(idx, dec);
        kCtrlOutput: begin
            control_lut = ctrl_zero();
            if (idx < kOutputCycles) begin
                control_lut.c_en = 1'b1;
            end
        end
        default:             control_lut = ctrl_zero();
    endcase
endfunction

function automatic CtrlState_e next_state_after_done(
    input CtrlState_e state,
    input logic dec,
    input logic [1:0] level,
    input logic [3:0] round
);
    unique case (state)
        kCtrlLoadData: next_state_after_done = kCtrlLoadKey;
        kCtrlLoadKey: begin
            if (extra_key_cycles(level) == 6'd0) begin
                next_state_after_done = kCtrlInit;
            end else begin
                next_state_after_done = kCtrlLoadExtraKey;
            end
        end
        kCtrlLoadExtraKey: next_state_after_done = kCtrlInit;
        kCtrlInit: next_state_after_done = dec ? kCtrlRoundAes128Dec : kCtrlRoundAes128Enc;
        kCtrlRoundAes128Enc,
        kCtrlRoundAes128Dec: begin
            if (round == (kAes128Rounds - 4'd1)) begin
                next_state_after_done = kCtrlFinalize;
            end else begin
                next_state_after_done = state;
            end
        end
        kCtrlFinalize: next_state_after_done = kCtrlOutput;
        default:       next_state_after_done = kCtrlLoadData;
    endcase
endfunction

logic [5:0] state_cycle_count;
logic       step_state;
logic       last_cycle;
CtrlSignals_t ctrl;

assign state_cycle_count = state_cycles(state_q, r_level);
assign step_state =
    ((state_q == kCtrlLoadData) || (state_q == kCtrlLoadKey) || (state_q == kCtrlLoadExtraKey)) ? i_valid :
    (state_q == kCtrlOutput) ? o_ready :
    1'b1;
assign last_cycle = (cycle_q == (state_cycle_count - 6'd1));

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_q <= kCtrlLoadData;
        cycle_q <= 6'd0;
        round_q <= 4'd0;
    end else if (step_state) begin
        if (last_cycle) begin
            state_q <= next_state_after_done(state_q, r_dec, r_level, round_q);
            cycle_q <= 6'd0;
            if ((state_q == kCtrlRoundAes128Enc) || (state_q == kCtrlRoundAes128Dec)) begin
                if (round_q == (kAes128Rounds - 4'd1)) begin
                    round_q <= 4'd0;
                end else begin
                    round_q <= round_q + 4'd1;
                end
            end else if (state_q == kCtrlInit) begin
                round_q <= 4'd0;
            end
        end else begin
            cycle_q <= cycle_q + 6'd1;
        end
    end
end

always_comb begin
    ctrl = control_lut(state_q, cycle_q, r_dec);
    if (!step_state) begin
        ctrl = ctrl_zero();
    end

	i_ready = (state_q == kCtrlLoadData) ||
              (state_q == kCtrlLoadKey) ||
              (state_q == kCtrlLoadExtraKey);
	o_valid = (state_q == kCtrlOutput);

	c_en     = ctrl.c_en;
	c_srow0  = ctrl.c_srow0;
	c_srow1  = ctrl.c_srow1;
	c_srow2  = ctrl.c_srow2;
	c_isrow0 = ctrl.c_isrow0;
	c_isrow1 = ctrl.c_isrow1;
	c_mixcol = ctrl.c_mixcol;
	c_ke0    = ctrl.c_ke0;
	c_ke1    = ctrl.c_ke1;
	c_ke2    = ctrl.c_ke2;
	c_kxor   = ctrl.c_kxor;
	c_ikxor  = ctrl.c_ikxor;
	c_add    = ctrl.c_add;
	c_sbox   = ctrl.c_sbox;
	c_rc_idx = {4'b0, round_q} + 8'd1;
end

endmodule
