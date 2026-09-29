// PosedgeDetector.sv
//
// Generates a single-clock-cycle pulse when `in` changes from 0 to 1.

module PosedgeDetector (
    input  logic clk,
    input  logic rst_n,
    input  logic in,
    output logic out
);

logic in_q;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_q <= 1'b0;
        out  <= 1'b0;
    end else begin
        out  <= in & ~in_q;
        in_q <= in;
    end
end

endmodule
