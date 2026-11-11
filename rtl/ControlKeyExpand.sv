// ControlKeyExpand.sv
//
// Generates the key-expansion control sequence after a synchronous start.

module ControlKeyExpand (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic is_ke2,
    output logic busy,
    output logic done,
    output logic c_ke0,
    output logic c_ke1,
    output logic c_ke2
);

logic       is_ke2_q;
logic [1:0] step;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        is_ke2_q <= 1'b0;
        step     <= 2'd0;
        busy     <= 1'b0;
        done     <= 1'b0;
        c_ke0    <= 1'b0;
        c_ke1    <= 1'b0;
        c_ke2    <= 1'b0;
    end else if (start && !busy) begin
        is_ke2_q <= is_ke2;
        step     <= 2'd1;
        busy     <= 1'b1;
        done     <= 1'b0;
        c_ke0    <= !is_ke2;
        c_ke1    <= 1'b0;
        c_ke2    <= is_ke2;
    end else if (busy && (step != 2'd0)) begin
        step <= (step == 2'd3) ? 2'd0 : step + 2'd1;
        busy <= 1'b1;
        done <= (step == 2'd3);
        c_ke0 <= 1'b0;
        c_ke1 <= !is_ke2_q;
        c_ke2 <= is_ke2_q;
    end else begin
        busy <= 1'b0;
        done <= 1'b0;
        c_ke0 <= 1'b0;
        c_ke1 <= 1'b0;
        c_ke2 <= 1'b0;
    end
end

endmodule
