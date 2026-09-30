
package AesPkg;

  // AES key expansion levels
  typedef enum logic [1:0] {
    kLevel128 = 2'b00,
    kLevel192 = 2'b01,
    kLevel256 = 2'b10
  } KeyLevel_e;

endpackage : AesPkg