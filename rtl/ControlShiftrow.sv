// ControlShiftrow.sv
//
// Generates the ShiftRows control sequence after an input-valid trigger.

module ControlShiftrow (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic i_valid,
    output logic o_valid,
    // [2:0] = {row3, row2, row1}
    output logic [2:0] c_srow
);

logic       i_valid_pulse;
logic       dec_q;
logic [1:0] step;
logic       active;

PosedgeDetector i_valid_posedge_detector (
    .clk(clk),
    .rst_n(rst_n),
    .in(i_valid),
    .out(i_valid_pulse)
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dec_q    <= 1'b0;
        step     <= 2'd0;
        active   <= 1'b0;
        o_valid  <= 1'b0;
        c_srow   <= 3'b000;
    end else begin
        c_srow   <= 3'b000;
        o_valid  <= 1'b0;

        if (i_valid_pulse) begin
            dec_q   <= r_dec;
            step    <= 2'd1;
            active  <= 1'b1;
            c_srow <= 3'b111;
        end else if (active) begin
            unique case (step)
                2'd1: begin
                    c_srow <= dec_q ? (c_srow >> 1) :(c_srow << 1);
                    step     <= 2'd2;
                end
                default: begin
                    c_srow <= dec_q ? (c_srow >> 1) :(c_srow << 1);
                    o_valid  <= 1'b1;
                    step     <= 2'd0;
                    active   <= 1'b0;
                end
            endcase
        end
    end
end

endmodule
