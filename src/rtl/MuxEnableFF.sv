
// MuxEnableFF.sv
//
// Wrapper of byte flipflop that only accept the value when enable is asserted
// The sel signal can choose which inputs to be stored into flipflop

module MuxEnableFF #(
    parameter WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    input logic en,
    input logic sel, // 0 select d0, 1 select d1
    input logic [WIDTH-1:0] d0,
    input logic [WIDTH-1:0] d1,
    output logic [WIDTH-1:0] q
);

logic [WIDTH-1:0] d;
assign d = sel ? d1 : d0;
EnableFF ff (clk, rst_n, en, d, q);

endmodule