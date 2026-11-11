// ControlAdd.sv
//
// Generates the eight-byte AddRoundKey/S-box control sequence.  Request
// fields are sampled when start is accepted and are held on o_sbox/o_xor so
// that the parent controller can use them when the operation completes.

module ControlAdd (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic       r_dec,
    input  logic       i_sbox,
    input  logic [1:0] i_xor,
    output logic       busy,
    output logic       done,
    output logic       c_add,
    output logic       c_sbox,
    output logic       c_kxor,
    output logic       c_ikxor,
    output logic       o_sbox,
    output logic [1:0] o_xor
);

logic       dec_q;
logic [2:0] cycle;

function automatic logic xor_enabled(
    input logic [1:0] xor_select,
    input logic [2:0] cycle_index
);
    case (xor_select)
        2'b10:  xor_enabled = (cycle_index < 3'd4);
        2'b01:  xor_enabled = (cycle_index >= 3'd4);
        2'b11:  xor_enabled = 1'b1;
        default: xor_enabled = 1'b0;
    endcase
endfunction

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dec_q   <= 1'b0;
        cycle   <= 3'd0;
        busy    <= 1'b0;
        done    <= 1'b0;
        c_add   <= 1'b0;
        c_sbox  <= 1'b0;
        c_kxor  <= 1'b0;
        c_ikxor <= 1'b0;
        o_sbox  <= 1'b0;
        o_xor   <= 2'b00;
    end else if (start && !busy) begin
        dec_q   <= r_dec;
        cycle   <= 3'd0;
        busy    <= 1'b1;
        done    <= 1'b0;
        c_add   <= 1'b1;
        c_sbox  <= i_sbox;
        c_kxor  <= !r_dec && xor_enabled(i_xor, 3'd0);
        c_ikxor <= r_dec && xor_enabled(i_xor, 3'd0);
        o_sbox  <= i_sbox;
        o_xor   <= i_xor;
    end else if (busy && (cycle == 3'd7)) begin
        cycle   <= 3'd0;
        busy    <= 1'b0;
        done    <= 1'b0;
        c_add   <= 1'b0;
        c_sbox  <= 1'b0;
        c_kxor  <= 1'b0;
        c_ikxor <= 1'b0;
    end else if (busy) begin
        c_add   <= 1'b1;
        c_sbox  <= o_sbox;
        c_kxor  <= !dec_q && xor_enabled(o_xor, cycle + 3'd1);
        c_ikxor <= dec_q && xor_enabled(o_xor, cycle + 3'd1);
        done    <= (cycle == 3'd6);

        if (cycle == 3'd6) begin
            cycle <= 3'd7;
        end else begin
            cycle <= cycle + 3'd1;
        end
    end else begin
        done    <= 1'b0;
        c_add   <= 1'b0;
        c_sbox  <= 1'b0;
        c_kxor  <= 1'b0;
        c_ikxor <= 1'b0;
    end
end

endmodule
