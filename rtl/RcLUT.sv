
// RcLUT.sv
//
// Lookup table for round constant in AES key expansion

module RcLUT (
  input        [4:0] i_data,
  output logic [7:0] o_data
);

always_comb begin
case (i_data)
  5'h00: o_data = 8'h01;
  5'h01: o_data = 8'h02;
  5'h02: o_data = 8'h04;
  5'h03: o_data = 8'h08;
  5'h04: o_data = 8'h10;
  5'h05: o_data = 8'h20;
  5'h06: o_data = 8'h40;
  5'h07: o_data = 8'h80;
  5'h08: o_data = 8'h1B;
  // 5'h09: o_data = 8'h36;
  // Reverse Rcon window for decryption; both directions increment c_rc_idx.
  // 5'h10: o_data = 8'h36;
  5'h17: o_data = 8'h1B;
  5'h18: o_data = 8'h80;
  5'h19: o_data = 8'h40;
  5'h1A: o_data = 8'h20;
  5'h1B: o_data = 8'h10;
  5'h1C: o_data = 8'h08;
  5'h1D: o_data = 8'h04;
  5'h1E: o_data = 8'h02;
  5'h1F: o_data = 8'h01;
  default: o_data = 8'h36;
endcase
end

endmodule
