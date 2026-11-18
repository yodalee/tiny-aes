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
 kE128Final,
 kD128Init,
 kD128Final,
 kE192Init,
 kE192Final,
 kD192Init,
 kD192Final,
 kE256Init,
 kE256Final,
 kD256Init,
 kD256Final,
 kOutput,
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
 kD256Round2
} state_e;

state_e state,state_n;
// count is the byte count for the streaming states and the number of
// ControlAdd requests launched in a processing state.
logic [5:0] count;
logic [3:0] round;
logic state_start;
logic start_add,done_add;
logic start_shiftrow,done_shiftrow;
logic start_mixcolumn,done_mixcolumn;
logic start_keyexpand,done_keyexpand;
logic state_done;
logic add_i_add,add_i_sbox;
logic [1:0] add_i_xor;
logic [4:0] add_i_ikxor;
logic keyexpand_is_ke2;
logic add_stateen,add_keyen;
logic [4:0] add_ikxor;

function automatic logic [5:0] key_cycles(input logic [1:0] l);
    case (l)
        2'b00:  key_cycles = 6'd16;
        2'b01:  key_cycles = 6'd24;
        default: key_cycles = 6'd32;
    endcase
endfunction
function automatic logic processing(input state_e s);
 processing=(s!=kLoadData)&&(s!=kLoadKey)&&(s!=kOutput);
endfunction

// The number of ControlAdd requests is a state property.  Most states need
// one request today, but keeping this as a state/count schedule is important:
// one state can launch ControlAdd more than once with a different setting.
function automatic logic [5:0] add_requests(input state_e s);
    case (s)
        kE128Init, kE128Final, kD128Init, kD128Final,
        kE192Init, kE192Final, kD192Init, kD192Final,
        kE256Init, kE256Final, kD256Init, kD256Final,
        kE128Round, kD128Round, kE192Round1, kE192Round2,
        kE192Round3, kE192Round4, kD192Round1, kD192Round2,
        kD192Round3, kE256Round1, kE256Round3, kE256Round4,
        kD256Round1, kD256Round2: begin
            if (s == kE192Round4) add_requests = 6'd2;
            else if (s == kD192Init) add_requests = 6'd3;
            else if (s == kD256Init) add_requests = 6'd4;
            else if (s == kE256Init) add_requests = 6'd6;
            else add_requests = 6'd2;
        end
        default: add_requests = 6'd0;
    endcase
endfunction

always_comb begin
    // Completion is connected to the final primitive in each LUT graph.
    state_done = 1'b0;
    case (state)
        kE128Init, kD128Final, kD192Final, kD256Final:
            state_done = count == 2 && done_add;
        kE128Round, kE192Round2, kE192Round3, kE256Round1,
        kE256Round3, kE256Round4:
            state_done = count == 2 && done_add;
        kE128Final, kE192Final, kE256Final:
            state_done = count == 2 && done_add;
        kD128Init: state_done = done_keyexpand;
        kD128Round, kD192Round1, kD192Round2, kD192Round3,
        kD256Round1, kD256Round2: state_done = done_shiftrow;
        kE192Init: state_done = done_mixcolumn;
        kE192Round1: state_done = count == 2 && done_add;
        kE192Round4: state_done = count == 2 && done_add;
        kD192Init, kD256Init: state_done = done_shiftrow;
        kE256Init: state_done = count == 6 && done_add;
        default: ;
    endcase
end

// Each primitive controller has its own schedule.  Keeping start, completion
// and settings together makes state-specific execution order visible here.
always_comb begin
    start_add = 1'b0;
    add_i_add = 1'b1;
    add_i_sbox = 1'b1;
    add_i_xor = 2'b00;
    add_i_ikxor = 5'b00000;

    // The state selects the request template; count only selects a request
    // within templates that require more than one variant.
    case (state)
        kE128Init: begin
            start_add = state_start || (done_add && count == 1);
        end

        kD128Final, kD192Final, kD256Final: begin
            start_add = state_start || (done_add && count == 1);
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
        end

        kE128Round: begin
            start_add = done_mixcolumn || (done_add && count == 1);
            add_i_xor = (count == 0) ? 2'b11 : 2'b10;
        end

        kE128Final, kE192Final, kE256Final: begin
            start_add = done_keyexpand || (done_add && count == 1);
            add_i_sbox = 1'b0;
            add_i_xor = 2'b11;
        end

        kD128Init: begin
            start_add = state_start || (done_add && count == 1);
            add_i_sbox = 1'b0;
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
            add_i_ikxor = 5'b10011;
        end

        kD128Round: begin
            start_add = state_start || (done_add && count == 1);
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
            add_i_ikxor = 5'b10011;
        end

        kE192Init: begin
            start_add = state_start || (done_add && count == 1);
        end

        kE192Round1: begin
            start_add = state_start || done_keyexpand;
            add_i_xor = (count == 1) ? 2'b11 : 2'b00;
        end

        kE192Round2: begin
            start_add = done_mixcolumn || (done_add && count == 1);
            add_i_xor = (count == 0) ? 2'b11 : 2'b10;
        end

        kE192Round3: begin
            start_add = done_mixcolumn || (done_add && count == 1);
            add_i_xor = 2'b11;
        end

        kE192Round4: begin
            // The LUT performs the first-half kxor request, expands the
            // key, then performs one full kxor request.
            start_add = done_mixcolumn || done_keyexpand;
            add_i_xor = (count == 0) ? 2'b10 :
                        (count == 1) ? 2'b11 : 2'b00;
        end

        kD192Init: begin
            // Rotate the key once, then process both state halves.
            start_add = state_start || (done_add && count < 3);
            add_i_add = count != 0;
            add_i_sbox = 1'b0;
            add_i_xor = (count == 2) ? 2'b01 : 2'b00;
            add_i_ikxor = 5'b00111;
        end

        kD192Round1: begin
            start_add = state_start || done_keyexpand;
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
            add_i_ikxor = 5'b11100;
        end

        kD192Round2: begin
            start_add = state_start || (done_add && count == 1);
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
            add_i_ikxor = 5'b11000;
        end

        kD192Round3: begin
            start_add = state_start || (done_add && count == 1);
            add_i_xor = (count == 0) ? 2'b10 :
                        (count == 1) ? 2'b01 : 2'b00;
            add_i_ikxor = (count == 0) ? 5'b00110 : 5'b00111;
        end

        // Rotate the 256-bit key twice, then process both state halves.
        kD256Init: begin
            start_add = state_start || (done_add && count < 4);
            add_i_add = count >= 2;
            add_i_sbox = 1'b0;
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
        end

        kD256Round1, kD256Round2: begin
            start_add = state_start || (done_add && count == 1);
            add_i_xor = (count == 1) ? 2'b01 : 2'b00;
            add_i_ikxor = 5'b11100;
        end

        kE256Init: begin
            // Requests 0--3 launch consecutively.  Request 4 waits for the
            // key expansion, and request 5 follows request 4 immediately.
            start_add = state_start ||
                        (done_add && ((count < 4) || (count == 5))) ||
                        done_keyexpand;
            if (count >= 2) begin
                add_i_add = 1'b0;
                add_i_sbox = 1'b0;
            end
            add_i_xor = (count == 4) ? 2'b11 :
                        (count == 5) ? 2'b10 : 2'b00;
        end

        kE256Round1: begin
            start_add = done_mixcolumn || (done_add && count == 1);
        end

        kE256Round3, kE256Round4: begin
            start_add = done_mixcolumn || (done_add && count == 1);
            add_i_xor = (count == 0) ? 2'b11 : 2'b10;
        end

        default: ;
    endcase
end

always_comb begin
    case (state)
        kE128Round, kE128Final, kE192Round2, kE192Round3, kE192Round4,
        kE192Final, kE256Round1, kE256Round3, kE256Round4, kE256Final:
            start_shiftrow = state_start;
        kD128Init: start_shiftrow = done_add && count == 2;
        kD128Round, kD192Round1, kD192Round2, kD192Round3,
        kD256Round1, kD256Round2: start_shiftrow = done_mixcolumn;
        kE192Init: start_shiftrow = done_add && count == 2;
        kD192Init: start_shiftrow = done_add && count == 3;
        kD256Init: start_shiftrow = done_add && count == 4;
        default: start_shiftrow = 1'b0;
    endcase
end

always_comb begin
    case (state)
        kE128Round, kE192Round2, kE192Round3, kE192Round4,
        kE256Round1, kE256Round3, kE256Round4:
            start_mixcolumn = done_shiftrow;
        kD128Round, kD192Round2, kD256Round1, kD256Round2:
            start_mixcolumn = done_add && count == 2;
        kD192Round1: start_mixcolumn = done_add && count == 2;
        kD192Round3: start_mixcolumn = done_add && count == 2;
        kE192Init: start_mixcolumn = done_shiftrow;
        default: start_mixcolumn = 1'b0;
    endcase
end

always_comb begin
    case (state)
        kE128Round, kE128Final, kE192Round3, kE192Final,
        kE256Round3, kE256Round4, kE256Final:
            start_keyexpand = state_start;
        kD128Init: start_keyexpand = done_add && count == 2;
        kD128Round, kD192Round2, kD256Round1, kD256Round2:
            start_keyexpand = done_add && count == 2;
        kE192Round1, kD192Round1: start_keyexpand = done_add && count == 1;
        kE192Round4: start_keyexpand = done_add && count == 1;
        // The key expansion follows the two data and two key-only requests.
        kE256Init: start_keyexpand = done_add && count == 4;
        default: start_keyexpand = 1'b0;
    endcase
    // The AES-256 LUT uses ke2 only for its second expansion step.  Init,
    // R4, and decryption R1 retain the normal ke0/ke1 sequence.
    keyexpand_is_ke2 = (state == kE256Round3 || state == kD256Round2);
end

ControlAdd i_control_add (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_add),
    .r_dec(r_dec[1]),
    .i_add(add_i_add),
    .i_sbox(add_i_sbox),
    .i_xor(add_i_xor),
    .i_ikxor(add_i_ikxor),
    .done(done_add),
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
    .done(done_shiftrow),
    .c_srow(c_srow)
);
ControlMixColumn i_control_mixcolumn (
    .clk(clk),
    .rst_n(rst_n),
    .r_dec(r_dec[1]),
    .start(start_mixcolumn),
    .done(done_mixcolumn),
    .c_mixcol(c_mixcol)
);
ControlKeyExpand i_control_keyexpand (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_keyexpand),
    .is_ke2(keyexpand_is_ke2),
    .done(done_keyexpand),
    .c_ke0(c_ke0),
    .c_ke1(c_ke1),
    .c_ke2(c_ke2)
);

always_comb begin
 state_n=state;
 case(state)
  kLoadData:if(i_valid&&count==6'd15) state_n=kLoadKey;
  kLoadKey:if(i_valid&&count==key_cycles(r_level)-1'b1) case({r_dec[1],r_level})
   3'b000:state_n=kE128Init;
   3'b001:state_n=kE192Init;
   3'b010,3'b011:state_n=kE256Init;
   3'b100:state_n=kD128Init;
   3'b101:state_n=kD192Init;
   3'b110,3'b111: state_n=kD256Init;
  endcase
  kE128Init:if(state_done)state_n=kE128Round;
  kE128Round:if(state_done&&round==8)state_n=kE128Final;
  kE128Final:if(state_done)state_n=kOutput;
  kD128Init:if(state_done)state_n=kD128Round;
  kD128Round:if(state_done&&round==8)state_n=kD128Final;
  kD128Final:if(state_done)state_n=kOutput;
  kE192Init:if(state_done)state_n=kE192Round1;
  kE192Round1:if(state_done)state_n=kE192Round2;
  kE192Round2:if(state_done) begin
   if(round==10)state_n=kE192Final; else state_n=kE192Round3;
  end
  kE192Round3:if(state_done)state_n=kE192Round4;
  kE192Round4:if(state_done)state_n=kE192Round2;
  kE192Final:if(state_done)state_n=kOutput;
  kD192Init:if(state_done)state_n=kD192Round1;
  kD192Round1:if(state_done)state_n=kD192Round2;
  kD192Round2:if(state_done) begin
   if(round==10)state_n=kD192Final; else state_n=kD192Round3;
  end
  kD192Round3:if(state_done)state_n=kD192Round1;
  kD192Final:if(state_done)state_n=kOutput;
  kE256Init:if(state_done)state_n=kE256Round1;
  kE256Round1:if(state_done&&round==1)state_n=kE256Round3;
  kE256Round3:if(state_done) begin
   if(round==12)state_n=kE256Final; else state_n=kE256Round4;
  end
  kE256Round4:if(state_done)state_n=kE256Round3;
  kE256Final:if(state_done)state_n=kOutput;
  kD256Init:if(state_done)state_n=kD256Round1;
  kD256Round1:if(state_done) begin
   if(round==12)state_n=kD256Final; else state_n=kD256Round2;
  end
  kD256Round2:if(state_done)state_n=kD256Round1;
  kD256Final:if(state_done)state_n=kOutput;
  kOutput:if(o_ready&&count==6'd15)state_n=kLoadData;
  default:state_n=kLoadData;
 endcase
end

always_ff @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin state<=kLoadData; count<='0; round<='0; state_start<=0; end
 else if((state==kLoadData||state==kLoadKey)&&!i_valid) begin end
 else if(state==kOutput&&!o_ready) begin end
 else begin
  state_start<=0;
  if(state==kLoadData||state==kLoadKey||state==kOutput) begin
   if(state_n!=state) count<='0; else count<=count+1'b1;
  end
  // In processing states count is the number of ControlAdd requests already
  // launched.  ControlAdd latches its settings on start, so advancing here
  // makes the next launch observe its own request index.
  if(processing(state) && start_add) count<=count+1'b1;
  if(processing(state)) begin
   if(state_done) begin
     count<='0;
     state<=state_n;
     if(processing(state_n)) state_start<=1;
     // A round state may deliberately transition back to itself.  Its round
     // counter therefore advances on schedule completion, not only when the
     // encoded state value changes.
     if(state[4])round<=round+1'b1;
   end
  end else if(state_n!=state) begin
   state<=state_n;
   if(processing(state_n)) state_start<=1;
   if(state==kLoadKey)round<=0;
  end
 end
end

// Processing controls are driven directly by their corresponding
// sub-controller.  Only the byte-stream handshakes need FSM-owned muxing.
assign c_stateen = (state == kLoadData) ? i_valid :
                   (state == kOutput)   ? o_ready : add_stateen;
assign c_loadkey = (state == kLoadKey) && i_valid;
assign c_keyen = (state == kLoadKey) ? i_valid : add_keyen;
assign c_ikxor = add_ikxor;
assign c_dec192_keysel = (state == kD192Round1 && add_keyen) ? 2'b01 :
                         (state == kD192Round2 && add_keyen) ? 2'b10 : 2'b00;
assign i_ready=(state==kLoadData)||(state==kLoadKey);
assign o_valid=(state==kOutput);
assign d_state=state;
endmodule
