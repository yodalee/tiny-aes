// ControlShiftrow.sv
//
// Generates the ShiftRows control sequence after a synchronous start.

module ControlShiftrow (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic start,
    // [2:0] = {row3, row2, row1}
    output logic [2:0] c_srow
);

logic [1:0] step;
logic       busy;
logic       direct_start;

assign direct_start = rst_n && start && !busy;

always_comb begin
    if (direct_start) c_srow = 3'b111;
    else if (busy) begin
        case (step)
            2'd1: c_srow = r_dec ? 3'b011 : 3'b110;
            2'd2: c_srow = r_dec ? 3'b001 : 3'b100;
            default: c_srow = 3'b000;
        endcase
    end else c_srow = 3'b000;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        step     <= 2'd0;
        busy     <= 1'b0;
    end else if (direct_start) begin
        step     <= 2'd1;
        busy     <= 1'b1;
    end else if (busy && (step == 2'd2)) begin
        step     <= 2'd0;
        busy     <= 1'b0;
    end else if (busy && (step == 2'd1)) begin
        step     <= 2'd2;
    end
end

endmodule
