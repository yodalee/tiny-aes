// ControlShiftrow.sv
//
// Generates the ShiftRows control sequence after a synchronous start.

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

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dec_q    <= 1'b0;
        step     <= 2'd0;
        busy     <= 1'b0;
        done     <= 1'b0;
        c_srow   <= 3'b000;
    end else if (start && !busy) begin
        dec_q    <= r_dec;
        step     <= 2'd1;
        busy     <= 1'b1;
        done     <= 1'b0;
        c_srow   <= 3'b111;
    end else if (busy && (step == 2'd1)) begin
        step     <= 2'd2;
        busy     <= 1'b1;
        done     <= 1'b0;
        c_srow   <= dec_q ? (c_srow >> 1) : (c_srow << 1);
    end else if (busy && (step == 2'd2)) begin
        step     <= 2'd0;
        busy     <= 1'b1;
        done     <= 1'b1;
        c_srow   <= dec_q ? (c_srow >> 1) : (c_srow << 1);
    end else begin
        busy     <= 1'b0;
        done     <= 1'b0;
        c_srow   <= 3'b000;
    end
end

endmodule
