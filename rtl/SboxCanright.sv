// Canright AES S-box / inverse S-box.
// Translated from model/test_canright.py.

module SboxCanright (
    input  logic       c_inv,
    input  logic [7:0] i_data,
    output logic [7:0] o_data
);

function automatic logic [7:0] a2x(input logic [7:0] n);
begin
    a2x[0] = n[0] ^ n[1] ^ n[2] ^ n[3] ^ n[6];
    a2x[1] = n[0] ^ n[5] ^ n[6];
    a2x[2] = n[0];
    a2x[3] = n[0] ^ n[1] ^ n[3] ^ n[4] ^ n[7];
    a2x[4] = n[0] ^ n[5] ^ n[6] ^ n[7];
    a2x[5] = n[0] ^ n[1] ^ n[5] ^ n[6];
    a2x[6] = n[0] ^ n[4] ^ n[5] ^ n[6];
    a2x[7] = n[0] ^ n[1] ^ n[2] ^ n[5] ^ n[6] ^ n[7];
end
endfunction

function automatic logic [7:0] s2x(input logic [7:0] n);
begin
    s2x[0] = n[0] ^ n[1] ^ n[4] ^ n[5] ^ n[6];
    s2x[1] = n[0] ^ n[3] ^ n[4];
    s2x[2] = n[2] ^ n[5] ^ n[7];
    s2x[3] = n[4] ^ n[6] ^ n[7];
    s2x[4] = n[0] ^ n[1] ^ n[3] ^ n[6];
    s2x[5] = n[4] ^ n[6];
    s2x[6] = n[0] ^ n[1] ^ n[4] ^ n[6];
    s2x[7] = n[4] ^ n[7];
end
endfunction

function automatic logic [7:0] x2s(input logic [7:0] n);
begin
    x2s[0] = n[1] ^ n[4] ^ n[6];
    x2s[1] = n[1] ^ n[4] ^ n[5];
    x2s[2] = n[0] ^ n[2] ^ n[3] ^ n[5] ^ n[6];
    x2s[3] = n[3] ^ n[4] ^ n[5] ^ n[6] ^ n[7];
    x2s[4] = n[3] ^ n[5] ^ n[7];
    x2s[5] = n[0] ^ n[6];
    x2s[6] = n[3] ^ n[7];
    x2s[7] = n[3] ^ n[5];
end
endfunction

function automatic logic [7:0] x2a(input logic [7:0] n);
begin
    x2a[0] = n[2];
    x2a[1] = n[1] ^ n[5];
    x2a[2] = n[1] ^ n[4] ^ n[5] ^ n[7];
    x2a[3] = n[1] ^ n[2] ^ n[3] ^ n[4] ^ n[5] ^ n[6];
    x2a[4] = n[1] ^ n[6];
    x2a[5] = n[0] ^ n[2] ^ n[3] ^ n[5] ^ n[6] ^ n[7];
    x2a[6] = n[0] ^ n[1] ^ n[3] ^ n[5] ^ n[6] ^ n[7];
    x2a[7] = n[1] ^ n[4];
end
endfunction

function automatic logic [1:0] g4_mul(input logic [1:0] x, input logic [1:0] y);
    logic a, b, c, d, e;
begin
    a = x[1];
    b = x[0];
    c = y[1];
    d = y[0];
    e = (a ^ b) & (c ^ d);
    g4_mul = {((a & c) ^ e), ((b & d) ^ e)};
end
endfunction

function automatic logic [1:0] g4_scale_n(input logic [1:0] x);
begin
    g4_scale_n = {x[0], x[1] ^ x[0]};
end
endfunction

function automatic logic [1:0] g4_scale_n2(input logic [1:0] x);
begin
    g4_scale_n2 = {x[1] ^ x[0], x[1]};
end
endfunction

function automatic logic [1:0] g4_square(input logic [1:0] x);
begin
    g4_square = {x[0], x[1]};
end
endfunction

function automatic logic [3:0] g16_mul(input logic [3:0] x, input logic [3:0] y);
    logic [1:0] a, b, c, d, e, p, q;
begin
    a = x[3:2];
    b = x[1:0];
    c = y[3:2];
    d = y[1:0];
    e = g4_scale_n(g4_mul(a ^ b, c ^ d));
    p = g4_mul(a, c) ^ e;
    q = g4_mul(b, d) ^ e;
    g16_mul = {p, q};
end
endfunction

function automatic logic [3:0] g16_sqr_nu(input logic [3:0] x);
    logic [1:0] a, b, p, c, q;
begin
    a = x[3:2];
    b = x[1:0];
    p = g4_square(a ^ b);
    c = g4_square(b);
    q = g4_scale_n2(c);
    g16_sqr_nu = {p, q};
end
endfunction

function automatic logic [3:0] g16_inverse(input logic [3:0] x);
    logic [1:0] a, b, c, d, e, p, q;
begin
    a = x[3:2];
    b = x[1:0];
    c = g4_scale_n(g4_square(a ^ b));
    d = g4_mul(a, b);
    e = g4_square(c ^ d);
    p = g4_mul(b, e);
    q = g4_mul(a, e);
    g16_inverse = {p, q};
end
endfunction

function automatic logic [7:0] g256_inverse(input logic [7:0] x);
    logic [3:0] a, b, c, d, e, p, q;
begin
    a = x[7:4];
    b = x[3:0];
    c = g16_sqr_nu(a ^ b);
    d = g16_mul(a, b);
    e = g16_inverse(c ^ d);
    p = g16_mul(b, e);
    q = g16_mul(a, e);
    g256_inverse = {p, q};
end
endfunction

function automatic logic [7:0] canright_sbox(input logic [7:0] n, input logic inv);
    logic [7:0] shifted, rebased, inverted, out_forward, out_inverse;
begin
    shifted = inv ? (n ^ 8'h63) : n;
    rebased = inv ? s2x(shifted) : a2x(shifted);
    inverted = g256_inverse(rebased);
    out_forward = x2s(inverted) ^ 8'h63;
    out_inverse = x2a(inverted);
    canright_sbox = inv ? out_inverse : out_forward;
end
endfunction

assign o_data = canright_sbox(i_data, c_inv);

endmodule
