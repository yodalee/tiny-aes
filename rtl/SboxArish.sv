// ARITH 2018 AES S-box / inverse S-box.
// Translated from model/test_arish.py.

module SboxArish (
    input  logic       c_inv,
    input  logic [7:0] i_data,
    output logic [7:0] o_data
);

localparam logic [1:0] ETA = 2'b01;
localparam logic [3:0] NU = 4'b0010;

function automatic logic [15:0] rebase_in(input logic [7:0] n);
begin
    rebase_in[0] = n[0] ^ n[5] ^ n[6];
    rebase_in[1] = n[0] ^ n[1] ^ n[2] ^ n[3] ^ n[6];
    rebase_in[2] = n[0] ^ n[1] ^ n[3] ^ n[4] ^ n[7];
    rebase_in[3] = n[0];
    rebase_in[4] = n[0] ^ n[1] ^ n[5] ^ n[6];
    rebase_in[5] = n[0] ^ n[5] ^ n[6] ^ n[7];
    rebase_in[6] = n[0] ^ n[1] ^ n[2] ^ n[5] ^ n[6] ^ n[7];
    rebase_in[7] = n[0] ^ n[4] ^ n[5] ^ n[6];
    rebase_in[8] = n[0] ^ n[3] ^ n[4];
    rebase_in[9] = n[0] ^ n[1] ^ n[4] ^ n[5] ^ n[6];
    rebase_in[10] = n[4] ^ n[6] ^ n[7];
    rebase_in[11] = n[2] ^ n[5] ^ n[7];
    rebase_in[12] = n[4] ^ n[6];
    rebase_in[13] = n[0] ^ n[1] ^ n[3] ^ n[6];
    rebase_in[14] = n[4] ^ n[7];
    rebase_in[15] = n[0] ^ n[1] ^ n[4] ^ n[6];
end
endfunction

function automatic logic [15:0] rebase_out(input logic [7:0] n);
begin
    rebase_out[0] = n[0] ^ n[5] ^ n[7];
    rebase_out[1] = n[0] ^ n[4] ^ n[5];
    rebase_out[2] = n[1] ^ n[2] ^ n[3] ^ n[4] ^ n[7];
    rebase_out[3] = n[2] ^ n[4] ^ n[5] ^ n[6] ^ n[7];
    rebase_out[4] = n[2] ^ n[4] ^ n[6];
    rebase_out[5] = n[1] ^ n[7];
    rebase_out[6] = n[2] ^ n[6];
    rebase_out[7] = n[2] ^ n[4];
    rebase_out[8] = n[3];
    rebase_out[9] = n[0] ^ n[4];
    rebase_out[10] = n[0] ^ n[4] ^ n[5] ^ n[6];
    rebase_out[11] = n[0] ^ n[2] ^ n[3] ^ n[4] ^ n[5] ^ n[7];
    rebase_out[12] = n[0] ^ n[7];
    rebase_out[13] = n[1] ^ n[2] ^ n[3] ^ n[4] ^ n[6] ^ n[7];
    rebase_out[14] = n[0] ^ n[1] ^ n[2] ^ n[4] ^ n[6] ^ n[7];
    rebase_out[15] = n[0] ^ n[5];
end
endfunction

function automatic logic [1:0] g4_mul(input logic [1:0] a, input logic [1:0] b);
    logic a1, a0, b1, b0;
    logic ap1, ap0, bp1, bp0;
    logic cp1, cp0, x1, x0;
begin
    a1 = a[1];
    a0 = a[0];
    b1 = b[1];
    b0 = b[0];

    ap1 = a1 ^ a0;
    ap0 = a0;
    bp1 = b1 ^ b0;
    bp0 = b0;

    cp0 = (ap0 & bp0) ^ (ap1 & bp1);
    cp1 = (ap1 & bp0) ^ (ap0 & bp1) ^ (ap1 & bp1);

    x0 = cp0;
    x1 = cp1 ^ cp0;
    g4_mul = {x1, x0};
end
endfunction

function automatic logic [3:0] g16_mul(input logic [3:0] a, input logic [3:0] b);
    logic [1:0] a1, a0, b1, b0;
    logic [1:0] ap, aq, bp, bq;
    logic [1:0] t, cp, cq, x1, x0;
begin
    a1 = a[3:2];
    a0 = a[1:0];
    b1 = b[3:2];
    b0 = b[1:0];

    ap = a1 ^ a0;
    aq = a0;
    bp = b1 ^ b0;
    bq = b0;

    t = g4_mul(ap, bp);
    cp = t ^ g4_mul(ap, bq) ^ g4_mul(aq, bp);
    cq = g4_mul(ETA, t) ^ g4_mul(aq, bq);

    x0 = cq;
    x1 = cp ^ cq;
    g16_mul = {x1, x0};
end
endfunction

function automatic logic [3:0] g16_inv(input logic [3:0] a);
begin
    unique case (a)
        4'h0: g16_inv = 4'h0;
        4'h1: g16_inv = 4'h4;
        4'h2: g16_inv = 4'hC;
        4'h3: g16_inv = 4'h8;
        4'h4: g16_inv = 4'h1;
        4'h5: g16_inv = 4'hA;
        4'h6: g16_inv = 4'hE;
        4'h7: g16_inv = 4'hD;
        4'h8: g16_inv = 4'h3;
        4'h9: g16_inv = 4'hB;
        4'hA: g16_inv = 4'h5;
        4'hB: g16_inv = 4'h9;
        4'hC: g16_inv = 4'h2;
        4'hD: g16_inv = 4'h7;
        4'hE: g16_inv = 4'h6;
        4'hF: g16_inv = 4'hF;
        default: g16_inv = 4'h0;
    endcase
end
endfunction

function automatic logic [3:0] g17(input logic [3:0] a, input logic [3:0] b);
    logic [3:0] c, d, sqr;
    logic a32, b32, a31, b31, a10, b10, a20, b20, ap, bp;
begin
    a32 = a[3] ^ a[2];
    b32 = b[3] ^ b[2];
    a31 = a[3] ^ a[1];
    b31 = b[3] ^ b[1];
    a10 = a[1] ^ a[0];
    b10 = b[1] ^ b[0];
    a20 = a[2] ^ a[0];
    b20 = b[2] ^ b[0];
    ap  = a31 ^ a20;
    bp  = b31 ^ b20;
    g17[3] = (a32 & b32) ^ (a31 & b31) ^ (a[3] & b[3]) ^ (a20 | b20);
    g17[2] = (a32 & b32) ^ (a31 | b31) ^ (a[2] & b[2]) ^ (ap & bp);
    g17[1] = (a[1] | b[1]) ^ (a20 & b20) ^ (a10 & b10) ^ (a31 & b31);
    g17[0] = (a[0] & b[0]) ^ (ap & bp) ^ (a10 | b10) ^ (a31 & b31);;
end
endfunction

function automatic logic [7:0] out_mul(
    input logic [3:0] a,
    input logic [3:0] b,
    input logic [3:0] e);
    logic [3:0] p, q;
    logic a32, a10, a20, a31, ap;
    logic b32, b10, b20, b31, bp;
    logic e31, e20;
    logic p4, p5, q4, q5;
begin
    // a-related
    a32 = a[3] ^ a[2];
    a31 = a[3] ^ a[1];
    a20 = a[2] ^ a[0];
    a10 = a[1] ^ a[0];
    ap = a32 ^ a10;
    // b-related
    b32 = b[3] ^ b[2];
    b31 = b[3] ^ b[1];
    b20 = b[2] ^ b[0];
    b10 = b[1] ^ b[0];
    bp = b32 ^ b10;
    // e-related
    e31 = e[3] ^ e[1];
    e20 = e[2] ^ e[0];
    // calculate p
    p4 = (b20 & e20) ^ (b31 & e31);
    p5 = (bp & e20) ^ (b20 & e31);
    p[3] = (b[2] & e[3]) ^ (b32 & e[2]) ^ p4;
    p[2] = (b[3] & e[2]) ^ (b32 & e[3]) ^ p5;
    p[1] = (b[0] & e[1]) ^ (b10 & e[0]) ^ p4;
    p[0] = (b[1] & e[0]) ^ (b10 & e[1]) ^ p5;
    // calculate q
    q4 = (a20 & e20) ^ (a31 & e31);
    q5 = (ap & e20) ^ (a20 & e31);
    q[3] = (a[2] & e[3]) ^ (a32 & e[2]) ^ q4;
    q[2] = (a[3] & e[2]) ^ (a32 & e[3]) ^ q5;
    q[1] = (a[0] & e[1]) ^ (a10 & e[0]) ^ q4;
    q[0] = (a[1] & e[0]) ^ (a10 & e[1]) ^ q5;
    out_mul = {p, q};
end
endfunction

function automatic logic [7:0] g256_inverse(input logic [7:0] n);
    logic [3:0] a, b, d, e;
    logic [7:0] pq;
begin
    a = n[7:4];
    b = n[3:0];
    d = g17(a, b);
    e = g16_inv(d);
    pq = out_mul(a, b, e);
    g256_inverse = pq;
end
endfunction

function automatic logic [7:0] arish_sbox(input logic [7:0] n, input logic inv);
    logic [7:0] shifted, nb, inverted;
    logic [15:0] input_rebase, output_rebase;
begin
    shifted = inv ? (n ^ 8'h63) : n;
    input_rebase = rebase_in(shifted);
    nb = inv ? input_rebase[15:8] : input_rebase[7:0];
    inverted = g256_inverse(nb);
    output_rebase = rebase_out(inverted);
    arish_sbox = inv ? output_rebase[15:8] : (output_rebase[7:0] ^ 8'h63);
end
endfunction

assign o_data = arish_sbox(i_data, c_inv);

endmodule
