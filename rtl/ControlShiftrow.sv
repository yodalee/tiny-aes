// ControlShiftrow.sv
//
// Generates the ShiftRows control sequence after an input-valid trigger.

module ControlShiftrow (
    input  logic clk,
    input  logic rst_n,
    input  logic r_dec,
    input  logic i_valid,
    output logic c_srow0,
    output logic c_srow1,
    output logic c_srow2,
    output logic c_isrow0,
    output logic c_isrow1
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
        c_srow0  <= 1'b0;
        c_srow1  <= 1'b0;
        c_srow2  <= 1'b0;
        c_isrow0 <= 1'b0;
        c_isrow1 <= 1'b0;
    end else begin
        c_srow0  <= 1'b0;
        c_srow1  <= 1'b0;
        c_srow2  <= 1'b0;
        c_isrow0 <= 1'b0;
        c_isrow1 <= 1'b0;

        if (i_valid_pulse) begin
            dec_q   <= r_dec;
            step    <= 2'd1;
            active  <= 1'b1;
            c_srow0 <= 1'b1;
        end else if (active) begin
            unique case (step)
                2'd1: begin
                    c_srow1  <= !dec_q;
                    c_isrow0 <= dec_q;
                    step     <= 2'd2;
                end
                default: begin
                    c_srow2  <= !dec_q;
                    c_isrow1 <= dec_q;
                    step     <= 2'd0;
                    active   <= 1'b0;
                end
            endcase
        end
    end
end

endmodule
