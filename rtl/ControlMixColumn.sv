// ControlMixColumn.sv
//
// Generates a MixColumns control pulse train after a synchronous start.

module ControlMixColumn (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic start,
    output logic c_mixcol
);

localparam logic [3:0] ENC_CYCLES = 4'd4;
localparam logic [3:0] DEC_CYCLES = 4'd12;

logic [3:0] cycles_left;
logic       busy;
logic       direct_start;

assign direct_start = rst_n && start && !busy;
assign c_mixcol = busy | direct_start;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycles_left <= 4'd0;
        busy        <= 1'b0;
    end else if (direct_start) begin
        cycles_left <= (r_dec ? DEC_CYCLES : ENC_CYCLES) - 4'd1;
        busy        <= 1'b1;
    end else if (busy && (cycles_left > 4'd1)) begin
        cycles_left <= cycles_left - 4'd1;
    end else if (busy) begin
        cycles_left <= 4'd0;
        busy        <= 1'b0;
    end else begin
        cycles_left <= 4'd0;
    end
end

endmodule
