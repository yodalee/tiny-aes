module ControlFsm (
    input  logic       clk,
    input  logic       rst_n,
    // 2'b0x: encryption; 2'b10: decrypt from the last-round key;
    // 2'b11: decrypt from the first-round key.
    input  logic [1:0] r_dec,
    input  logic [1:0] r_level,
    input  logic       i_valid,
    output logic       i_ready,
    input  logic       o_ready,
    output logic       o_valid,
    output logic [4:0] d_state,
    output logic       c_stateen,
    output logic [2:0] c_srow,
    output logic       c_mixcol,
    output logic       c_loadkey,
    output logic       c_keyen,
    output logic       c_ke0,
    output logic       c_ke1,
    output logic       c_ke2,
    output logic       c_kxor,
    output logic       c_resetrc,
    output logic [4:0] c_ikxor,
    output logic [1:0] c_dec192_keysel,
    output logic       c_add,
    output logic       c_sbox
);

// Keep these values stable: d_state is exported for debug.
typedef enum logic [4:0] {
 kLoadData,
 kLoadKey,
 kE128Init,
 kEFinal,
 kD128Init,
 kD128Final,
 kE192Init,
 kD128Key,
 kD192Init,
 kD192Final,
 kE256Init,
 kD192Key,
 kD256Init,
 kD256Final,
 kOutput,
 kD256Key1,
 kE128Round = 5'd16,
 kD128Round,
 kE192Round1,
 kE192Round2,
 kE192Round3,
 kE192Round4,
 kD192Round1,
 kD192Round2,
 kD192Round3,
 kE256Round1,
 kE256Round3,
 kE256Round4,
 kD256Round1,
 kD256Round2,
 kD256Key2
} state_e;

state_e state, state_n;
logic [5:0] cycle_q;
logic [3:0] round_q;
logic state_end;
logic start_add, start_shiftrow, start_mixcolumn, start_keyexpand;
logic [2:0] add_index, add_last_index;
logic add_i_add, add_i_sbox;
logic [1:0] add_i_xor;
logic [4:0] add_i_ikxor;
logic keyexpand_is_ke2;
logic add_stateen, add_keyen;
logic [4:0] add_ikxor;

function automatic logic [5:0] key_cycles(input logic [1:0] level);
    case (level)
        2'b00:  key_cycles = 6'd16;
        2'b01:  key_cycles = 6'd24;
        default: key_cycles = 6'd32;
    endcase
endfunction

function automatic logic processing(input state_e s);
    processing = (s != kLoadData) && (s != kLoadKey) && (s != kOutput);
endfunction

function automatic logic key_state(input state_e s);
    key_state = (s == kD128Key) || (s == kD192Key) ||
                (s == kD256Key1) || (s == kD256Key2);
endfunction

// Shared AES processing-state lengths match the cycle-counted FSM from
// 6ec65ad. The newer first-key decryption preparation states use the existing
// primitive schedule: key expansion plus the required key-XOR operations.
function automatic logic [5:0] cycles(
    input state_e s,
    input logic [3:0] key_round
);
    case (s)
        kE128Init, kD128Final, kD192Final, kD256Final:
            cycles = 6'd16;
        kEFinal, kD128Init, kE192Round1:
            cycles = 6'd20;
        kE128Round, kE192Round2, kE192Round3,
        kE256Round1, kE256Round3, kE256Round4, kE192Init:
            cycles = 6'd23;
        kE192Round4, kD192Init:
            cycles = 6'd27;
        kD128Round, kD192Round2, kD192Round3,
        kD256Round1, kD256Round2:
            cycles = 6'd31;
        kD192Round1, kD256Init:
            cycles = 6'd35;
        kE256Init:
            cycles = 6'd52;
        kD128Key, kD256Key1, kD256Key2:
            cycles = 6'd20;
        kD192Key:
            cycles = (key_round == 4'd7) ? 6'd20 : 6'd28;
        default:
            cycles = 6'd1;
    endcase
endfunction

// Assert Add starts at the first cycle of each eight-cycle request. Gaps are
// reserved for the other subcontrollers; the Add controller itself no longer
// reports completion to the FSM.
always_comb begin
    start_add = 1'b0;
    add_index = 3'd0;
    case (state)
        kE128Init, kD128Init, kD128Round, kE192Init,
        kD128Final, kD192Final, kD256Final,
        kD192Round2, kD192Round3, kD256Round1, kD256Round2: begin
            start_add = (cycle_q == 6'd0) || (cycle_q == 6'd8);
            add_index = (cycle_q == 6'd8) ? 3'd1 : 3'd0;
        end
        kE128Round, kE192Round2, kE192Round3,
        kE256Round1, kE256Round3, kE256Round4: begin
            start_add = (cycle_q == 6'd7) || (cycle_q == 6'd15);
            add_index = (cycle_q == 6'd15) ? 3'd1 : 3'd0;
        end
        kEFinal: begin
            start_add = (cycle_q == 6'd4) || (cycle_q == 6'd12);
            add_index = (cycle_q == 6'd12) ? 3'd1 : 3'd0;
        end
        kD128Key, kD256Key1, kD256Key2: begin
            start_add = (cycle_q == 6'd4) || (cycle_q == 6'd12);
            add_index = (cycle_q == 6'd12) ? 3'd1 : 3'd0;
        end
        kD192Key: begin
            start_add = (cycle_q == 6'd4) || (cycle_q == 6'd12) ||
                        ((round_q != 4'd7) && (cycle_q == 6'd20));
            case (cycle_q)
                6'd12: add_index = 3'd1;
                6'd20: add_index = 3'd2;
                default: add_index = 3'd0;
            endcase
        end
        kE192Round1, kD192Round1: begin
            start_add = (cycle_q == 6'd0) || (cycle_q == 6'd12);
            add_index = (cycle_q == 6'd12) ? 3'd1 : 3'd0;
        end
        kE192Round4: begin
            start_add = (cycle_q == 6'd7) || (cycle_q == 6'd19);
            add_index = (cycle_q == 6'd19) ? 3'd1 : 3'd0;
        end
        kD192Init: begin
            start_add = (cycle_q == 6'd0) || (cycle_q == 6'd8) ||
                        (cycle_q == 6'd16);
            add_index = {1'b0, cycle_q[4:3]};
        end
        kD256Init: begin
            start_add = (cycle_q == 6'd0) || (cycle_q == 6'd8) ||
                        (cycle_q == 6'd16) || (cycle_q == 6'd24);
            add_index = {1'b0, cycle_q[4:3]};
        end
        kE256Init: begin
            start_add = (cycle_q == 6'd0) || (cycle_q == 6'd8) ||
                        (cycle_q == 6'd16) || (cycle_q == 6'd24) ||
                        (cycle_q == 6'd36) || (cycle_q == 6'd44);
            if (cycle_q <= 6'd24) add_index = {1'b0, cycle_q[4:3]};
            else add_index = (cycle_q == 6'd36) ? 3'd4 : 3'd5;
        end
        default: ;
    endcase

    add_i_add = 1'b1;
    add_i_sbox = 1'b1;
    add_i_xor = 2'b00;
    add_i_ikxor = 5'b00000;
    add_last_index = 3'd1;

    if (key_state(state)) begin
        add_i_add = 1'b0;
        add_i_sbox = 1'b0;
        if (state == kD192Key && round_q != 4'd7)
            add_last_index = 3'd2;
        add_i_xor = (add_index == add_last_index) ? 2'b10 : 2'b11;
    end else begin
        case (state)
            kD128Final, kD192Final, kD256Final:
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
            kE128Round, kE192Round2, kE256Round3, kE256Round4:
                add_i_xor = (add_index == 3'd0) ? 2'b11 : 2'b10;
            kEFinal: begin
                add_i_sbox = 1'b0;
                add_i_xor = 2'b11;
            end
            kD128Init: begin
                add_i_sbox = 1'b0;
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
                add_i_ikxor = 5'b10011;
            end
            kD128Round: begin
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
                add_i_ikxor = 5'b10011;
            end
            kE192Round1:
                add_i_xor = (add_index == 3'd1) ? 2'b11 : 2'b00;
            kE192Round3:
                add_i_xor = 2'b11;
            kE192Round4:
                add_i_xor = (add_index == 3'd0) ? 2'b10 : 2'b11;
            kD192Init: begin
                add_i_add = (add_index != 3'd0);
                add_i_sbox = 1'b0;
                add_i_xor = (add_index == 3'd2) ? 2'b01 : 2'b00;
                add_i_ikxor = 5'b00111;
            end
            kD192Round1: begin
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
                add_i_ikxor = 5'b11100;
            end
            kD192Round2: begin
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
                add_i_ikxor = 5'b11000;
            end
            kD192Round3: begin
                add_i_xor = (add_index == 3'd0) ? 2'b10 :
                            (add_index == 3'd1) ? 2'b01 : 2'b00;
                add_i_ikxor = (add_index == 3'd0) ? 5'b00110 : 5'b00111;
            end
            kD256Init: begin
                add_i_add = (add_index >= 3'd2);
                add_i_sbox = 1'b0;
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
            end
            kD256Round1, kD256Round2: begin
                add_i_xor = (add_index == 3'd1) ? 2'b01 : 2'b00;
                add_i_ikxor = 5'b11100;
            end
            kE256Init: begin
                if (add_index >= 3'd2) begin
                    add_i_add = 1'b0;
                    add_i_sbox = 1'b0;
                end
                add_i_xor = (add_index == 3'd4) ? 2'b11 :
                            (add_index == 3'd5) ? 2'b10 : 2'b00;
            end
            default: ;
        endcase
    end
end

always_comb begin
    start_shiftrow = 1'b0;
    case (state)
        kE128Round, kEFinal, kE192Round2, kE192Round3, kE192Round4,
        kE256Round1, kE256Round3, kE256Round4:
            start_shiftrow = (cycle_q == 6'd0);
        kD128Init, kE192Init:
            start_shiftrow = (cycle_q == 6'd16);
        kD192Init:
            start_shiftrow = (cycle_q == 6'd24);
        kD256Init:
            start_shiftrow = (cycle_q == 6'd32);
        kD128Round, kD192Round2, kD192Round3, kD256Round1, kD256Round2:
            start_shiftrow = (cycle_q == 6'd28);
        kD192Round1:
            start_shiftrow = (cycle_q == 6'd32);
        default: ;
    endcase
end

always_comb begin
    start_mixcolumn = 1'b0;
    case (state)
        kE128Round, kE192Round2, kE192Round3, kE192Round4,
        kE256Round1, kE256Round3, kE256Round4:
            start_mixcolumn = (cycle_q == 6'd3);
        kD128Round, kD192Round2, kD192Round3, kD256Round1, kD256Round2:
            start_mixcolumn = (cycle_q == 6'd16);
        kD192Round1:
            start_mixcolumn = (cycle_q == 6'd20);
        kE192Init:
            start_mixcolumn = (cycle_q == 6'd19);
        default: ;
    endcase
end

always_comb begin
    start_keyexpand = 1'b0;
    case (state)
        kE128Round, kEFinal, kE192Round3, kE256Round3, kE256Round4,
        kD128Key, kD192Key, kD256Key1, kD256Key2:
            start_keyexpand = (cycle_q == 6'd0);
        kD128Init, kD128Round, kD192Round2, kD256Round1, kD256Round2:
            start_keyexpand = (cycle_q == 6'd16);
        kE192Round1, kD192Round1:
            start_keyexpand = (cycle_q == 6'd8);
        kE192Round4:
            start_keyexpand = (cycle_q == 6'd15);
        kE256Init:
            start_keyexpand = (cycle_q == 6'd32);
        default: ;
    endcase
end

// AES-256's second expansion uses ke2; this selection depends only on state.
always_comb begin
    keyexpand_is_ke2 = (state == kE256Round3) ||
                       (state == kD256Round2) ||
                       (state == kD256Key2);
end

ControlAdd i_control_add (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_add),
    .r_dec(r_dec[1] && !key_state(state)),
    .i_add(add_i_add),
    .i_sbox(add_i_sbox),
    .i_xor(add_i_xor),
    .i_ikxor(add_i_ikxor),
    .c_keyen(add_keyen),
    .c_add(c_add),
    .c_stateen(add_stateen),
    .c_sbox(c_sbox),
    .c_kxor(c_kxor),
    .c_ikxor(add_ikxor)
);

ControlShiftrow i_control_shiftrow (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec[1]),
    .start(start_shiftrow),
    .c_srow(c_srow)
);

ControlMixColumn i_control_mixcolumn (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec[1]),
    .start(start_mixcolumn),
    .c_mixcol(c_mixcol)
);

ControlKeyExpand i_control_keyexpand (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_keyexpand),
    .is_ke2(keyexpand_is_ke2),
    .c_ke0(c_ke0),
    .c_ke1(c_ke1),
    .c_ke2(c_ke2)
);

always_comb begin
    state_end = 1'b0;
    case (state)
        kLoadData: state_end = i_valid && (cycle_q == 6'd15);
        kLoadKey: state_end = i_valid && (cycle_q == key_cycles(r_level) - 6'd1);
        kOutput: state_end = o_ready && (cycle_q == 6'd15);
        default:
            if (processing(state))
                state_end = (cycle_q == cycles(state, round_q) - 6'd1);
    endcase
end

always_comb begin
    state_n = state;
    case (state)
        kLoadData:
            if (state_end) state_n = kLoadKey;
        kLoadKey:
            if (state_end) begin
                if (!r_dec[1]) begin
                    case (r_level)
                        2'b00: state_n = kE128Init;
                        2'b01: state_n = kE192Init;
                        default: state_n = kE256Init;
                    endcase
                end else if (r_dec[0]) begin
                    case (r_level)
                        2'b00: state_n = kD128Key;
                        2'b01: state_n = kD192Key;
                        default: state_n = kD256Key1;
                    endcase
                end else begin
                    case (r_level)
                        2'b00: state_n = kD128Init;
                        2'b01: state_n = kD192Init;
                        default: state_n = kD256Init;
                    endcase
                end
            end
        kE128Init: state_n = kE128Round;
        kE128Round: if (round_q == 4'd8) state_n = kEFinal;
        kEFinal: state_n = kOutput;
        kD128Key: if (round_q == 4'd9) state_n = kD128Init;
        kD128Init: state_n = kD128Round;
        kD128Round: if (round_q == 4'd8) state_n = kD128Final;
        kD128Final: state_n = kOutput;
        kE192Init: state_n = kE192Round1;
        kE192Round1: state_n = kE192Round2;
        kE192Round2:
            state_n = (round_q == 4'd10) ? kEFinal : kE192Round3;
        kE192Round3: state_n = kE192Round4;
        kE192Round4: state_n = kE192Round2;
        kD192Key: if (round_q == 4'd7) state_n = kD192Init;
        kD192Init: state_n = kD192Round1;
        kD192Round1: state_n = kD192Round2;
        kD192Round2:
            state_n = (round_q == 4'd10) ? kD192Final : kD192Round3;
        kD192Round3: state_n = kD192Round1;
        kD192Final: state_n = kOutput;
        kE256Init: state_n = kE256Round1;
        kE256Round1: if (round_q == 4'd1) state_n = kE256Round3;
        kE256Round3:
            state_n = (round_q == 4'd12) ? kEFinal : kE256Round4;
        kE256Round4: state_n = kE256Round3;
        kD256Key1:
            state_n = (round_q == 4'd12) ? kD256Init : kD256Key2;
        kD256Key2: state_n = kD256Key1;
        kD256Init: state_n = kD256Round1;
        kD256Round1:
            state_n = (round_q == 4'd12) ? kD256Final : kD256Round2;
        kD256Round2: state_n = kD256Round1;
        kD256Final: state_n = kOutput;
        kOutput: if (state_end) state_n = kLoadData;
        default: state_n = kLoadData;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state   <= kLoadData;
        cycle_q <= 6'd0;
        round_q <= 4'd0;
    end else if (((state == kLoadData) || (state == kLoadKey)) && !i_valid) begin
        // Hold the input byte position until a byte is accepted.
    end else if ((state == kOutput) && !o_ready) begin
        // Hold the output byte position until a byte is accepted.
    end else if (state_end) begin
        state   <= state_n;
        cycle_q <= 6'd0;
        if (key_state(state)) begin
            if (!key_state(state_n)) round_q <= 4'd0;
            else round_q <= round_q + 4'd1;
        end else if (state[4]) begin
            round_q <= round_q + 4'd1;
        end else if (state == kLoadKey) begin
            round_q <= 4'd0;
        end
    end else begin
        cycle_q <= cycle_q + 6'd1;
    end
end

assign c_stateen = (state == kLoadData) ? i_valid :
                   (state == kOutput)   ? o_ready : add_stateen;
assign c_loadkey = (state == kLoadKey) && i_valid;
assign c_keyen = (state == kLoadKey) ? i_valid : add_keyen;
assign c_ikxor = add_ikxor;
assign c_resetrc = state_end && key_state(state) && !key_state(state_n);
assign c_dec192_keysel = (state == kD192Round1 && add_keyen) ? 2'b01 :
                         (state == kD192Round2 && add_keyen) ? 2'b10 : 2'b00;
assign i_ready = (state == kLoadData) || (state == kLoadKey);
assign o_valid = (state == kOutput);
assign d_state = state;

endmodule
