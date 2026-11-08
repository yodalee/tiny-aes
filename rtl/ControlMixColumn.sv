// ControlMixColumn.sv
//
// Generates the MixColumns control pulse train after a start pulse.  `done`
// is high during the final active cycle.

module ControlMixColumn (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic start,
    output logic busy,
    output logic done,
    output logic c_mixcol
);

localparam logic [3:0] ENC_CYCLES = 4'd4;
localparam logic [3:0] DEC_CYCLES = 4'd12;

logic [3:0] cycles_left;

assign busy     = (cycles_left != 4'd0);
assign done     = (cycles_left == 4'd1);
assign c_mixcol = start || busy;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycles_left <= 4'd0;
    end else if (start && !busy) begin
        cycles_left <= (r_dec ? DEC_CYCLES : ENC_CYCLES) - 4'd1;
    end else if (busy) begin
        cycles_left <= cycles_left - 4'd1;
    end
end

endmodule
