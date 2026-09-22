import galois
import numpy as np
import unittest

X2A = [0x64, 0x78, 0x6E, 0x8C, 0x68, 0x29, 0xDE, 0x60]
A2X = [0x98, 0xF3, 0xF2, 0x48, 0x09, 0x81, 0xA9, 0xFF]
X2S = [0x58, 0x2D, 0x9E, 0x0B, 0xDC, 0x04, 0x03, 0x24]
S2X = [0x8C, 0x79, 0x05, 0xEB, 0x12, 0x04, 0x51, 0x53]

def rebase(n: int, base: list[int]) -> int:
    ret = 0
    for offset in range(7, -1, -1):
        if n & 1 == 1:
            ret ^= base[offset]
        n >>= 1
    return ret

def g4_mul(x: int, y: int) -> int:
    # Each number should be in GF(4), less than 4
    a = (x & 0x2) >> 1
    b = (x & 0x1)
    c = (y & 0x2) >> 1
    d = (y & 0x1)
    e = (a ^ b) & (c ^ d)
    p = (a & c) ^ e
    q = (b & d) ^ e
    return (p << 1) | q

def g4_scaleN(x: int) -> int:
    # scale by N = omega^2 in GF4
    a = (x & 0x2) >> 1
    b = (x & 0x1)
    p = b
    q = a ^ b
    return (p << 1) | q

def g4_scaleN2(x: int) -> int:
    # scale by N^2 = omega in GF4
    a = (x & 0x2) >> 1
    b = (x & 0x1)
    p = a ^ b
    q = a
    return (p << 1) | q

def g4_square(x: int) -> int:
    a = (x & 0x2) >> 1
    b = (x & 0x1)
    return (b << 1) | a

def g16_mul(x: int, y: int) -> int:
    # Each number should be in GF(16), less than 16
    a = (x & 0xC) >> 2
    b = (x & 0x3)
    c = (y & 0xC) >> 2
    d = (y & 0x3)
    e = g4_mul(a ^ b, c ^ d)
    e = g4_scaleN(e)
    p = g4_mul(a, c) ^ e
    q = g4_mul(b, d) ^ e
    return (p << 2) | q

def g16_sqr_nu(x: int) -> int:
    # square and scale by nu in GF16
    # nu = beta^8 = N^2 * alpha^2, N = w^2
    a = (x & 0xC) >> 2
    b = (x & 0x3)
    p = g4_square(a ^ b)
    c = g4_square(b)
    q = g4_scaleN2(c)
    return (p << 2) | q

def g16_inverse(x: int) -> int:
    a = (x & 0xC) >> 2
    b = x & 0x3

    c = g4_square(a ^ b)
    c = g4_scaleN(c)
    d = g4_mul(a, b)
    e = g4_square(c ^ d) # g4 inverse is identical to square
    p = g4_mul(b, e)
    q = g4_mul(a, e)
    return (p << 2) | q

def g256_inverse(x: int) -> int:
    a = (x & 0xf0) >> 4
    b = x & 0x0f
    c = g16_sqr_nu(a ^ b)
    d = g16_mul(a, b)
    e = g16_inverse(c ^ d)
    p = g16_mul(b, e)
    q = g16_mul(a, e)
    return (p << 4) | q

def cal_sbox(n: int) -> int:
    nb = rebase(n, A2X)
    ib = g256_inverse(nb)
    i = rebase(ib, X2S)
    return i ^ 0x63

def cal_isbox(n: int) -> int:
    nb = rebase(n ^ 0x63, S2X)
    ib = g256_inverse(nb)
    i = rebase(ib, X2A)
    return i

def main():
    sbox = [0] * 256
    isbox = [0] * 256

    for i in range(256):
        sbox[i] = cal_sbox(i)
        isbox[i] = cal_isbox(i)

    for row in range(16):
        for col in range(16):
            print(f"{sbox[16 * row + col]:02x}", end = " ")
        print()
    print()

    for row in range(16):
        for col in range(16):
            print(f"{isbox[16 * row + col]:02x}", end = " ")
        print()

if __name__ == "__main__":
    main()