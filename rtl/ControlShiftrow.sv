// ControlShiftrow.sv
//
// Generates the three ShiftRows control cycles after a start pulse.  `done`
// is high during the final control cycle, allowing the owner to advance on
// that same edge.

module ControlShiftrow (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic start,
    output logic busy,
    output logic done,
    // [2:0] = {row3, row2, row1}
    output logic [2:0] c_srow
);

logic       dec_q;
logic [1:0] step;

assign busy = (step != 2'd0);
assign done = (step == 2'd2);

// The first control is combinationally available with start.  This lets a
// parent issue start at the beginning of a phase without paying a bubble.
always_comb begin
    c_srow = 3'b000;
    case (step)
        2'd0: if (start) c_srow = 3'b111;
        2'd1: c_srow = dec_q ? 3'b011 : 3'b110;
        2'd2: c_srow = dec_q ? 3'b001 : 3'b100;
        default: ;
    endcase
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dec_q    <= 1'b0;
        step     <= 2'd0;
    end else begin
        if (start && !busy) begin
            dec_q   <= r_dec;
            step    <= 2'd1;
        end else if (busy) begin
            if (done) begin
                step    <= 2'd0;
            end else begin
                step <= step + 1'b1;
            end
        end
    end
end

endmodule
