// ControlMixColumn.sv
//
// Generates a MixColumns control pulse train after a synchronous start.

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

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycles_left <= 4'd0;
        busy        <= 1'b0;
        done        <= 1'b0;
        c_mixcol    <= 1'b0;
    end else if (start && !busy) begin
        cycles_left <= (r_dec ? DEC_CYCLES : ENC_CYCLES) - 4'd1;
        busy        <= 1'b1;
        done        <= 1'b0;
        c_mixcol    <= 1'b1;
    end else if (busy && (cycles_left != 4'd0)) begin
        cycles_left <= cycles_left - 4'd1;
        busy        <= 1'b1;
        done        <= (cycles_left == 4'd1);
        c_mixcol    <= 1'b1;
    end else begin
        busy        <= 1'b0;
        done        <= 1'b0;
        c_mixcol    <= 1'b0;
    end
end

endmodule
