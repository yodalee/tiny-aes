// ControlAdd.sv
//
// Generates an eight-byte state/key control sequence.  A request can perform
// AddRoundKey/S-box work, key XOR work, or key-only rotation.

module ControlAdd (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic       r_dec,
    input  logic       i_add,
    input  logic       i_sbox,
    input  logic [1:0] i_xor,
    output logic       busy,
    output logic       done,
    output logic       c_keyen,
    output logic       c_add,
    output logic       c_stateen,
    output logic       c_sbox,
    output logic       c_kxor,
    output logic       c_ikxor
);

logic       add_q;
logic       sbox_q;
logic [1:0] xor_q;
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

// Every invocation advances the key stream.  State advances for either data
// operation, so an i_add=0/i_sbox=0/i_xor=0 request is an eight-byte key-only
// rotation.
assign c_stateen = c_add | c_sbox;
assign c_keyen   = busy;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        add_q   <= 1'b0;
        sbox_q  <= 1'b0;
        xor_q   <= 2'b00;
        cycle   <= 3'd0;
        busy    <= 1'b0;
        done    <= 1'b0;
        c_add   <= 1'b0;
        c_sbox  <= 1'b0;
        c_kxor  <= 1'b0;
        c_ikxor <= 1'b0;
    end else if (start && (!busy || done)) begin
        add_q   <= i_add;
        sbox_q  <= i_sbox;
        xor_q   <= i_xor;
        cycle   <= 3'd0;
        busy    <= 1'b1;
        done    <= 1'b0;
        c_add   <= i_add;
        c_sbox  <= i_sbox;
        c_kxor  <= !r_dec && xor_enabled(i_xor, 3'd0);
        c_ikxor <= r_dec && xor_enabled(i_xor, 3'd0);
    end else if (busy && (cycle == 3'd7)) begin
        cycle   <= 3'd0;
        busy    <= 1'b0;
        done    <= 1'b0;
        c_add   <= 1'b0;
        c_sbox  <= 1'b0;
        c_kxor  <= 1'b0;
        c_ikxor <= 1'b0;
    end else if (busy) begin
        c_add   <= add_q;
        c_sbox  <= sbox_q;
        c_kxor  <= !r_dec && xor_enabled(xor_q, cycle + 3'd1);
        c_ikxor <= r_dec && xor_enabled(xor_q, cycle + 3'd1);
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
