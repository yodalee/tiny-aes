// ControlMixColumn.sv
//
// Generates the MixColumns control pulse train after an input-valid trigger.

module ControlMixColumn (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic i_valid,
    output logic o_valid,
    output logic c_mixcol
);

localparam logic [3:0] ENC_CYCLES = 4'd4;
localparam logic [3:0] DEC_CYCLES = 4'd12;

logic       i_valid_pulse;
logic [3:0] cycles_left;

PosedgeDetector i_valid_posedge_detector (
    .clk(clk),
    .rst_n(rst_n),
    .in(i_valid),
    .out(i_valid_pulse)
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycles_left <= 4'd0;
        o_valid     <= 1'b0;
        c_mixcol   <= 1'b0;
    end else if (i_valid_pulse) begin
        cycles_left <= (r_dec ? DEC_CYCLES : ENC_CYCLES) - 4'd1;
        o_valid     <= 1'b0;
        c_mixcol   <= 1'b1;
    end else if (cycles_left != 4'd0) begin
        cycles_left <= cycles_left - 4'd1;
        o_valid     <= (cycles_left == 4'd1);
        c_mixcol   <= 1'b1;
    end else begin
        o_valid     <= 1'b0;
        c_mixcol   <= 1'b0;
    end
end

endmodule
