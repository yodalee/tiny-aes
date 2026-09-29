
// RcLUT.sv
//
// Lookup table for round constant in AES key expansion

module RcLUT (
  input        [7:0] i_data,
  output logic [7:0] o_data
);

always_comb begin
case (i_data)
  8'h00: o_data = 8'h01;
  8'h01: o_data = 8'h02;
  8'h02: o_data = 8'h04;
  8'h03: o_data = 8'h08;
  8'h04: o_data = 8'h10;
  8'h05: o_data = 8'h20;
  8'h06: o_data = 8'h40;
  8'h07: o_data = 8'h80;
  8'h08: o_data = 8'h1B;
  default: o_data = 8'h36; // for i_data == 9
endcase
end

endmodule