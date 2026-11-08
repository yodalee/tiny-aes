// Byte-serial AES controller.  Control is decoded from compact phase ranges,
// rather than a wide microcode ROM.
module ControlFsm (
    input logic clk, rst_n, r_dec, input logic [1:0] r_level,
    input logic i_valid, output logic i_ready, input logic o_ready,
    output logic o_valid, output logic c_stateen, output logic [2:0] c_srow,
    output logic c_mixcol, output logic c_loadkey, c_keyen,
    output logic c_ke0, c_ke1, c_ke2, c_kxor, output logic [4:0] c_ikxor,
    output logic [1:0] c_dec192_keysel, output logic c_add, c_sbox
);

typedef enum logic [4:0] {
    kLoadData, kLoadKey, kE128Init, kEKeyRound, kEFinal,
    kD128Init, kD128Round, kDFinal, kE192Init, kE192R1, kE192R2, kE192R3, kE192R4,
    kD192Init, kD192R1A, kD192R1B, kD192R2, kD192R3,
    kE256InitA, kE256InitB, kE256R1, kE256R3,
    kD256InitA, kD256InitB, kD256R1, kD256R2, kOutput
} state_e;

state_e state, state_n;
logic [4:0] cycle_q;
logic [3:0] round_q;
logic dec_q;
logic [1:0] level_q;
logic p_data, p_sbox, p_keyshift, p_ke0, p_ke1, p_ke2, p_kxor;
logic [4:0] p_ikxor;
logic [1:0] p_keysel;
logic p_srow_start, p_mix_start, srow_busy, srow_done, mix_busy, mix_done;

ControlShiftrow i_shiftrow (
    .clk, .rst_n, .r_dec(dec_q), .start(p_srow_start),
    .busy(srow_busy), .done(srow_done), .c_srow
);
ControlMixColumn i_mixcolumn (
    .clk, .rst_n, .r_dec(dec_q), .start(p_mix_start),
    .busy(mix_busy), .done(mix_done), .c_mixcol
);

function automatic logic [4:0] key_last(input logic [1:0] level);
    case (level)
        2'b00: key_last = 15;
        2'b01: key_last = 23;
        default: key_last = 31;
    endcase
endfunction

function automatic logic [4:0] last_cycle(input state_e s);
    case (s)
        kE128Init, kDFinal: last_cycle = 15;
        kEKeyRound, kE192R2, kE192R3, kE256R1, kE256R3, kE192Init: last_cycle = 22;
        kEFinal, kD128Init, kE192R1, kE256InitB: last_cycle = 19;
        kD128Round, kD192R2, kD192R3, kD256R1, kD256R2: last_cycle = 30;
        kE192R4, kD192Init: last_cycle = 26;
        kD192R1A, kD256InitA, kE256InitA: last_cycle = 31;
        kD192R1B, kD256InitB: last_cycle = 2;
        default: last_cycle = 0;
    endcase
endfunction

function automatic logic is_round(input state_e s);
    case (s)
        kEKeyRound, kD128Round, kE192R1, kE192R2, kE192R3, kE192R4,
        kD192R1B, kD192R2, kD192R3, kE256R1, kE256R3, kD256R1, kD256R2:
            is_round = 1'b1;
        default: is_round = 1'b0;
    endcase
endfunction

always_comb begin
    state_n = state;
    case (state)
        kLoadData: if (i_valid && cycle_q == 15) state_n = kLoadKey;
        kLoadKey: if (i_valid && cycle_q == key_last(level_q))
            case ({dec_q, level_q})
                3'b000: state_n = kE128Init;
                3'b001: state_n = kE192Init;
                3'b010, 3'b011: state_n = kE256InitA;
                3'b100: state_n = kD128Init;
                3'b101: state_n = kD192Init;
                default: state_n = kD256InitA;
            endcase
        kE128Init: state_n = kEKeyRound;
        kEKeyRound: case (level_q)
            2'b00: state_n = (round_q == 8) ? kEFinal : kEKeyRound;
            2'b01: state_n = kE192R4;
            default: state_n = kE256R3;
        endcase
        kEFinal, kDFinal: state_n = kOutput;
        kD128Init: state_n = kD128Round;
        kD128Round: if (round_q == 8) state_n = kDFinal;
        kE192Init: state_n = kE192R1;
        kE192R1: state_n = kE192R2;
        kE192R2: state_n = (round_q == 10) ? kEFinal : kE192R3;
        kE192R3: state_n = kE192R4;
        kE192R4: state_n = kE192R2;
        kD192Init: state_n = kD192R1A;
        kD192R1A: state_n = kD192R1B;
        kD192R1B: state_n = kD192R2;
        kD192R2: state_n = (round_q == 10) ? kDFinal : kD192R3;
        kD192R3: state_n = kD192R1A;
        kE256InitA: state_n = kE256InitB;
        kE256InitB: state_n = kE256R1;
        kE256R1: state_n = (round_q == 1) ? kE256R3 : kE256R1;
        kE256R3: state_n = (round_q == 12) ? kEFinal : kEKeyRound;
        kD256InitA: state_n = kD256InitB;
        kD256InitB: state_n = kD256R1;
        kD256R1: state_n = (round_q == 12) ? kDFinal : kD256R2;
        kD256R2: state_n = kD256R1;
        kOutput: if (o_ready && cycle_q == 15) state_n = kLoadData;
        default: state_n = kLoadData;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= kLoadData; cycle_q <= '0; round_q <= '0;
        dec_q <= 1'b0; level_q <= '0;
    end else if ((state == kLoadData || state == kLoadKey) && !i_valid) begin
    end else if (state == kOutput && !o_ready) begin
    end else begin
        if (state == kLoadData && cycle_q == 0) begin
            dec_q <= r_dec; level_q <= r_level;
        end
        if ((state == kLoadData && cycle_q == 15) ||
            (state == kLoadKey && cycle_q == key_last(level_q)) ||
            (state == kOutput && cycle_q == 15) ||
            ((state != kLoadData && state != kLoadKey && state != kOutput) &&
             cycle_q == last_cycle(state))) begin
            state <= state_n; cycle_q <= '0;
            if (is_round(state)) round_q <= round_q + 1'b1;
            else if (state == kLoadKey) round_q <= '0;
        end else cycle_q <= cycle_q + 1'b1;
    end
end

always_comb begin
    p_data=0; p_sbox=0; p_keyshift=0; p_ke0=0; p_ke1=0; p_ke2=0; p_kxor=0;
    p_ikxor='0; p_keysel='0; p_srow_start=0; p_mix_start=0;
    case (state)
        kE128Init: begin p_data=1; p_sbox=1; p_keyshift=1; end
        kEKeyRound: begin
            p_srow_start=(cycle_q==0); p_mix_start=(cycle_q==3);
            if (cycle_q==0) p_ke0=1;
            else if (cycle_q<=3) p_ke1=1;
            else if (cycle_q>=7 && (level_q==2'b01 || cycle_q<=18)) begin
                p_data=1; p_sbox=1; p_kxor=1;
            end else if (cycle_q>=19) begin p_data=1; p_sbox=1; p_keyshift=1; end
        end
        kEFinal: begin
            p_srow_start=(cycle_q==0);
            if (cycle_q==0) p_ke0=1;
            else if (cycle_q<=3) p_ke1=1;
            else if (cycle_q<=15) begin p_data=1; p_kxor=1; end
            else begin p_data=1; p_keyshift=1; end
        end
        kD128Init: begin
            if (cycle_q<16) begin p_data=1; p_keyshift=1; if (cycle_q>=12) p_ikxor=5'b10011; end
            p_srow_start=(cycle_q==16);
            if (cycle_q==16) p_ke0=1; else if (cycle_q>=17) p_ke1=1;
        end
        kD128Round: begin
            if (cycle_q<16) begin p_data=1; p_sbox=1; p_keyshift=1; if (cycle_q>=12) p_ikxor=5'b10011; end
            p_mix_start=(cycle_q==16); p_srow_start=(cycle_q==28);
            if (cycle_q==16) p_ke0=1; else if (cycle_q>=17 && cycle_q<=19) p_ke1=1;
        end
        kDFinal: begin p_data=1; p_sbox=1; p_keyshift=1; end
        kE192Init: begin
            if (cycle_q<16) begin p_data=1; p_sbox=1; p_keyshift=1; end
            p_srow_start=(cycle_q==16); p_mix_start=(cycle_q==19);
        end
        kE192R1: begin
            if (cycle_q<8) begin p_data=1; p_sbox=1; p_keyshift=1; end
            else if (cycle_q==8) p_ke0=1; else if (cycle_q<=11) p_ke1=1;
            else begin p_data=1; p_sbox=1; p_keyshift=1; p_kxor=1; end
        end
        kE192R2: begin
            p_srow_start=(cycle_q==0); p_mix_start=(cycle_q==3);
            if (cycle_q>=7 && cycle_q<=18) begin p_data=1; p_sbox=1; p_kxor=1; end
            else if (cycle_q>=19) begin p_data=1; p_sbox=1; p_keyshift=1; end
        end
        kE192R3: begin
            p_srow_start=(cycle_q==0); p_mix_start=(cycle_q==3);
            if (cycle_q==0) p_ke0=1;
            else if (cycle_q<=3) p_ke1=1;
            else if (cycle_q>=7) begin p_data=1; p_sbox=1; p_keyshift=1; p_kxor=1; end
        end
        kE192R4: begin
            p_srow_start=(cycle_q==0); p_mix_start=(cycle_q==3);
            if (cycle_q>=7 && cycle_q<=10) begin p_data=1; p_sbox=1; p_kxor=1; end
            else if (cycle_q>=11 && cycle_q<=14) begin p_data=1; p_sbox=1; p_keyshift=1; end
            else if (cycle_q==15) p_ke0=1;
            else if (cycle_q>=16 && cycle_q<=18) p_ke1=1;
            else if (cycle_q>=19) begin p_data=1; p_sbox=1; p_keyshift=1; p_kxor=1; end
        end
        kD192Init: begin
            if (cycle_q<8) p_keyshift=1;
            else if (cycle_q<24) begin p_data=1; p_keyshift=1; if (cycle_q>=20) p_ikxor=5'b00111; end
            p_srow_start=(cycle_q==24);
        end
        kD192R1A: begin
            if (cycle_q<8 || (cycle_q>=12 && cycle_q<20)) begin
                p_data=1; p_sbox=1; p_keyshift=1; p_keysel=2'b01;
                if (cycle_q>=16) p_ikxor=5'b11100;
            end else if (cycle_q==8) p_ke0=1; else if (cycle_q<=11) p_ke1=1;
            p_mix_start=(cycle_q==20);
        end
        kD192R1B: p_srow_start=(cycle_q==0);
        kD192R2: begin
            if (cycle_q<16) begin p_data=1; p_sbox=1; p_keyshift=1; p_keysel=2'b10; if (cycle_q>=12) p_ikxor=5'b11000; end
            p_mix_start=(cycle_q==16); p_srow_start=(cycle_q==28);
            if (cycle_q==16) p_ke0=1; else if (cycle_q>=17 && cycle_q<=19) p_ke1=1;
        end
        kD192R3: begin
            if (cycle_q<16) begin
                p_data=1; p_sbox=1; p_keyshift=1;
                if (cycle_q<4) p_ikxor=5'b00110; else if (cycle_q>=12) p_ikxor=5'b00111;
            end
            p_mix_start=(cycle_q==16); p_srow_start=(cycle_q==28);
        end
        kE256InitA: begin
            if (cycle_q<16) begin p_data=1; p_sbox=1; p_keyshift=1; end
            else p_keyshift=1;
        end
        kE256InitB: begin
            if (cycle_q==0) p_ke0=1;
            else if (cycle_q<=3) p_ke1=1;
            else if (cycle_q<=15) p_kxor=1;
            else p_keyshift=1;
        end
        kE256R1: begin
            p_srow_start=(cycle_q==0); p_mix_start=(cycle_q==3);
            if (cycle_q>=7) begin p_data=1; p_sbox=1; p_keyshift=1; end
        end
        kE256R3: begin
            p_srow_start=(cycle_q==0); p_mix_start=(cycle_q==3);
            if (cycle_q<=3) p_ke2=1;
            else if (cycle_q>=7 && cycle_q<=18) begin p_data=1; p_sbox=1; p_kxor=1; end
            else if (cycle_q>=19) begin p_data=1; p_sbox=1; p_keyshift=1; end
        end
        kD256InitA: begin
            if (cycle_q<16) p_keyshift=1; else begin p_data=1; p_keyshift=1; end
        end
        kD256InitB: p_srow_start=(cycle_q==0);
        kD256R1, kD256R2: begin
            if (cycle_q<16) begin p_data=1; p_sbox=1; p_keyshift=1; if (cycle_q>=12) p_ikxor=5'b11100; end
            p_mix_start=(cycle_q==16); p_srow_start=(cycle_q==28);
            if (state==kD256R1) begin if (cycle_q==16) p_ke0=1; else if (cycle_q>=17 && cycle_q<=19) p_ke1=1; end
            else if (cycle_q>=16 && cycle_q<=19) p_ke2=1;
        end
        default: ;
    endcase
end

always_comb begin
    c_stateen=p_data; c_add=p_data; c_sbox=p_sbox;
    c_keyen=p_keyshift;
    c_ke0=p_ke0; c_ke1=p_ke1; c_ke2=p_ke2; c_kxor=p_kxor;
    c_ikxor=p_ikxor; c_dec192_keysel=p_keysel;
    c_loadkey=(state==kLoadKey) && i_valid;
    if (state==kLoadData) c_stateen=i_valid;
    if (state==kLoadKey) c_keyen=i_valid;
    if (state==kOutput) c_stateen=o_ready;
end

assign i_ready=(state==kLoadData)||(state==kLoadKey);
assign o_valid=(state==kOutput);
endmodule
