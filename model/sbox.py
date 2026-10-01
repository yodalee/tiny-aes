import unittest

class CanrightSbox:
    # Canright, D. (2005). A Very Compact S-Box for AES.
    # In Cryptographic Hardware and Embedded Systems – CHES 2005. 
    # Springer. https://doi.org/10.1007/11545262_32
    X2A = [0x64, 0x78, 0x6E, 0x8C, 0x68, 0x29, 0xDE, 0x60]
    A2X = [0x98, 0xF3, 0xF2, 0x48, 0x09, 0x81, 0xA9, 0xFF]
    X2S = [0x58, 0x2D, 0x9E, 0x0B, 0xDC, 0x04, 0x03, 0x24]
    S2X = [0x8C, 0x79, 0x05, 0xEB, 0x12, 0x04, 0x51, 0x53]

    def rebase(self, n: int, base: list[int]) -> int:
        ret = 0
        for offset in range(7, -1, -1):
            if n & 1 == 1:
                ret ^= base[offset]
            n >>= 1
        return ret

    def g4_mul(self, x: int, y: int) -> int:
        # Each number should be in GF(4), less than 4
        a = (x & 0x2) >> 1
        b = (x & 0x1)
        c = (y & 0x2) >> 1
        d = (y & 0x1)
        e = (a ^ b) & (c ^ d)
        p = (a & c) ^ e
        q = (b & d) ^ e
        return (p << 1) | q

    def g4_scaleN(self, x: int) -> int:
        # scale by N = omega^2 in GF4
        a = (x & 0x2) >> 1
        b = (x & 0x1)
        p = b
        q = a ^ b
        return (p << 1) | q

    def g4_scaleN2(self, x: int) -> int:
        # scale by N^2 = omega in GF4
        a = (x & 0x2) >> 1
        b = (x & 0x1)
        p = a ^ b
        q = a
        return (p << 1) | q

    def g4_square(self, x: int) -> int:
        a = (x & 0x2) >> 1
        b = (x & 0x1)
        return (b << 1) | a

    def g16_mul(self, x: int, y: int) -> int:
        # Each number should be in GF(16), less than 16
        a = (x & 0xC) >> 2
        b = (x & 0x3)
        c = (y & 0xC) >> 2
        d = (y & 0x3)
        e = self.g4_mul(a ^ b, c ^ d)
        e = self.g4_scaleN(e)
        p = self.g4_mul(a, c) ^ e
        q = self.g4_mul(b, d) ^ e
        return (p << 2) | q

    def g16_sqr_nu(self, x: int) -> int:
        # square and scale by nu in GF16
        # nu = beta^8 = N^2 * alpha^2, N = w^2
        a = (x & 0xC) >> 2
        b = (x & 0x3)
        p = self.g4_square(a ^ b)
        c = self.g4_square(b)
        q = self.g4_scaleN2(c)
        return (p << 2) | q

    def g16_inverse(self, x: int) -> int:
        a = (x & 0xC) >> 2
        b = x & 0x3

        c = self.g4_square(a ^ b)
        c = self.g4_scaleN(c)
        d = self.g4_mul(a, b)
        e = self.g4_square(c ^ d) # g4 inverse is identical to square
        p = self.g4_mul(b, e)
        q = self.g4_mul(a, e)
        return (p << 2) | q

    def g256_inverse(self, x: int) -> int:
        a = (x & 0xf0) >> 4
        b = x & 0x0f
        c = self.g16_sqr_nu(a ^ b)
        d = self.g16_mul(a, b)
        e = self.g16_inverse(c ^ d)
        p = self.g16_mul(b, e)
        q = self.g16_mul(a, e)
        return (p << 4) | q

    def cal_sbox(self, n: int) -> int:
        nb = self.rebase(n, self.A2X)
        ib = self.g256_inverse(nb)
        i = self.rebase(ib, self.X2S)
        return i ^ 0x63

    def cal_isbox(self, n: int) -> int:
        nb = self.rebase(n ^ 0x63, self.S2X)
        ib = self.g256_inverse(nb)
        i = self.rebase(ib, self.X2A)
        return i

class TowerSbox:
    # A. Reyhani-Masoleh, M. Taha and D. Ashmawy, 
    # "New Area Record for the AES Combined S-Box/Inverse S-Box," 
    # 2018 IEEE 25th Symposium on Computer Arithmetic (ARITH), Amherst, MA, USA, 2018, pp. 145-152, 
    # doi: 10.1109/ARITH.2018.8464780.
    A2X = [0x64, 0xF3, 0xF1, 0x84, 0x06, 0x42, 0x56, 0xFF]
    X2S = [0x2D, 0x58, 0x0B, 0x9E, 0x04, 0xDC, 0x24, 0x03]
    S2X = [0x4C, 0xB6, 0x0A, 0xD7, 0x21, 0x08, 0xA2, 0xA3]
    X2A = [0x78, 0x64, 0x8C, 0x6E, 0x29, 0x68, 0x60, 0xDE]

    def rebase(self, n:int, base: list[int]) -> int:
        ret = 0
        for offset in range(7, -1, -1):
            if n & 1 == 1:
                ret ^= base[offset]
            n >>= 1
        return ret

    def expo17(self, a:int, b:int) -> int:
        # d0 =(a01b01 ⊕ a02b02 ⊕ a0b0 ⊕ (a13 ∨ b13)),
        # d1 =(a01b01 ⊕ (a02 ∨ b02) ⊕ a1b1 ⊕ apbp),
        # d2 = ((a2 ∨ b2) ⊕ a13b13 ⊕ a23b23 ⊕ a02b02),
        # d3 =(a3b3 ⊕ apbp ⊕ (a23 ∨ b23) ⊕ a02b02).
        a0 = ((a >> 3) & 0x1) == 1
        a1 = ((a >> 2) & 0x1) == 1
        a2 = ((a >> 1) & 0x1) == 1
        a3 = ((a >> 0) & 0x1) == 1
        b0 = ((b >> 3) & 0x1) == 1
        b1 = ((b >> 2) & 0x1) == 1
        b2 = ((b >> 1) & 0x1) == 1
        b3 = ((b >> 0) & 0x1) == 1
        a01 = a0 ^ a1
        a02 = a0 ^ a2
        a13 = a1 ^ a3
        a23 = a2 ^ a3
        b01 = b0 ^ b1
        b02 = b0 ^ b2
        b13 = b1 ^ b3
        b23 = b2 ^ b3
        ap = a02 ^ a13
        bp = b02 ^ b13
        # d0 =(a01b01 ⊕ a02b02 ⊕ a0b0 ⊕ (a13 ∨ b13)),
        # d1 =(a01b01 ⊕ (a02 ∨ b02) ⊕ a1b1 ⊕ apbp),
        # d2 = ((a2 ∨ b2) ⊕ a13b13 ⊕ a23b23 ⊕ a02b02),
        # d3 =(a3b3 ⊕ apbp ⊕ (a23 ∨ b23) ⊕ a02b02).
        d0 = (a01 & b01) ^ (a02 & b02) ^ (a0 & b0) ^ (a13 | b13)
        d1 = (a01 & b01) ^ (a02 | b02) ^ (a1 & b1) ^ (ap & bp)
        d2 = (a2 | b2) ^ (a13 | b13) ^ (a23 & b23) ^ (a02 & b02)
        d3 = (a3 & b3) ^ (ap & bp) ^ (a23 | b23) ^ (a02 & b02)
        return ((1 << 3) if d0 else 0) | \
               ((1 << 2) if d1 else 0) | \
               ((1 << 1) if d2 else 0) | \
               ((1 << 0) if d3 else 0)


    def g4_inverse(self, n:int) -> int:
        # since there are a lot of not operation
        # It will be more convenient to convert to Bool
        d0 = ((n >> 3) & 0x1) == 1
        d1 = ((n >> 2) & 0x1) == 1
        d2 = ((n >> 1) & 0x1) == 1
        d3 = ((n >> 0) & 0x1) == 1
        nd0 = not d0
        nd1 = not d1
        nd2 = not d2
        nd3 = not d3
        e0 = not ((nd3 | (not (d0 ^ d1))) and (nd2 | (not (nd0 | d3))))
        e1 = not ((d2 | nd3 | (d0 ^ d1)) and (nd2 | (not (d1 | nd3))))
        e2 = not ((nd1 | (not (d2 ^ d3))) and (nd0 | (not (nd2 | d1))))
        e3 = not ((d0 | nd1 | (d2 ^ d3)) and (nd0 | (not (d3 | nd1))))
        return ((1 << 3) if e0 else 0) | \
               ((1 << 2) if e1 else 0) | \
               ((1 << 1) if e2 else 0) | \
               ((1 << 0) if e3 else 0)

    def output_multiplier(self, a:int, b:int, e:int) -> int:
        # output w, z where w = mul(b, e), z = mul(a, e)
        # z0 = a1e0 ⊕ a01e1 ⊕ z4
        # z1 = a0e1 ⊕ a01e0 ⊕ z5
        # z2 = a3e2 ⊕ a23e3 ⊕ z4
        # z3 = a2e3 ⊕ a23e2 ⊕ z5,
        # z4 = a13e13 ⊕ a02e02
        # z5 = ape13 ⊕ a13e02.
        a0 = ((a >> 3) & 0x1) == 1
        a1 = ((a >> 2) & 0x1) == 1
        a2 = ((a >> 1) & 0x1) == 1
        a3 = ((a >> 0) & 0x1) == 1
        b0 = ((b >> 3) & 0x1) == 1
        b1 = ((b >> 2) & 0x1) == 1
        b2 = ((b >> 1) & 0x1) == 1
        b3 = ((b >> 0) & 0x1) == 1
        e0 = ((e >> 3) & 0x1) == 1
        e1 = ((e >> 2) & 0x1) == 1
        e2 = ((e >> 1) & 0x1) == 1
        e3 = ((e >> 0) & 0x1) == 1
        a01 = a0 ^ a1
        a23 = a2 ^ a3
        a13 = a1 ^ a3
        a02 = a0 ^ a2
        ap = a02 ^ a13
        b01 = b0 ^ b1
        b23 = b2 ^ b3
        b13 = b1 ^ b3
        b02 = b0 ^ b2
        bp = b02 ^ b13
        e02 = e0 ^ e2
        e13 = e1 ^ e3
        # z
        z4 = (a13 & e13) ^ (a02 & e02)
        z5 = (ap & e13) ^ (a13 & e02)
        z0 = (a1 & e0) ^ (a01 & e1) ^ z4
        z1 = (a0 & e1) ^ (a01 & e0) ^ z5
        z2 = (a3 & e2) ^ (a23 & e3) ^ z4
        z3 = (a2 & e3) ^ (a23 & e2) ^ z5
        z = ((1 << 3) if z0 else 0) | \
            ((1 << 2) if z1 else 0) | \
            ((1 << 1) if z2 else 0) | \
            ((1 << 0) if z3 else 0)
        # w
        w4 = (b13 & e13) ^ (b02 & e02)
        w5 = (bp & e13) ^ (b13 & e02)
        w0 = (b1 & e0) ^ (b01 & e1) ^ w4
        w1 = (b0 & e1) ^ (b01 & e0) ^ w5
        w2 = (b3 & e2) ^ (b23 & e3) ^ w4
        w3 = (b2 & e3) ^ (b23 & e2) ^ w5
        w = ((1 << 3) if w0 else 0) | \
            ((1 << 2) if w1 else 0) | \
            ((1 << 1) if w2 else 0) | \
            ((1 << 0) if w3 else 0)
        return (w << 4) | z

    def g256_inverse(self, x:int) -> int:
        a = (x & 0xF0) >> 4
        b = (x & 0xF)
        d = self.expo17(a, b)
        e = self.g4_inverse(d)
        o = self.output_multiplier(a, b, e)
        return o

    def cal_sbox(self, n: int) -> int:
        nb = self.rebase(n, self.A2X)
        ib = self.g256_inverse(nb)
        i = self.rebase(ib, self.X2S)
        return i ^ 0x63


    def cal_isbox(self, n: int) -> int:
        nb = self.rebase(n ^ 0x63, self.S2X)
        ib = self.g256_inverse(nb)
        i = self.rebase(ib, self.X2A)
        return i

# FIPS-197, Tables 4 and 6.  Keeping every entry here makes this test
# independent of the implementation being checked.
SBOX_GOLDEN = (
    0x63, 0x7C, 0x77, 0x7B, 0xF2, 0x6B, 0x6F, 0xC5, 0x30, 0x01, 0x67, 0x2B, 0xFE, 0xD7, 0xAB, 0x76,
    0xCA, 0x82, 0xC9, 0x7D, 0xFA, 0x59, 0x47, 0xF0, 0xAD, 0xD4, 0xA2, 0xAF, 0x9C, 0xA4, 0x72, 0xC0,
    0xB7, 0xFD, 0x93, 0x26, 0x36, 0x3F, 0xF7, 0xCC, 0x34, 0xA5, 0xE5, 0xF1, 0x71, 0xD8, 0x31, 0x15,
    0x04, 0xC7, 0x23, 0xC3, 0x18, 0x96, 0x05, 0x9A, 0x07, 0x12, 0x80, 0xE2, 0xEB, 0x27, 0xB2, 0x75,
    0x09, 0x83, 0x2C, 0x1A, 0x1B, 0x6E, 0x5A, 0xA0, 0x52, 0x3B, 0xD6, 0xB3, 0x29, 0xE3, 0x2F, 0x84,
    0x53, 0xD1, 0x00, 0xED, 0x20, 0xFC, 0xB1, 0x5B, 0x6A, 0xCB, 0xBE, 0x39, 0x4A, 0x4C, 0x58, 0xCF,
    0xD0, 0xEF, 0xAA, 0xFB, 0x43, 0x4D, 0x33, 0x85, 0x45, 0xF9, 0x02, 0x7F, 0x50, 0x3C, 0x9F, 0xA8,
    0x51, 0xA3, 0x40, 0x8F, 0x92, 0x9D, 0x38, 0xF5, 0xBC, 0xB6, 0xDA, 0x21, 0x10, 0xFF, 0xF3, 0xD2,
    0xCD, 0x0C, 0x13, 0xEC, 0x5F, 0x97, 0x44, 0x17, 0xC4, 0xA7, 0x7E, 0x3D, 0x64, 0x5D, 0x19, 0x73,
    0x60, 0x81, 0x4F, 0xDC, 0x22, 0x2A, 0x90, 0x88, 0x46, 0xEE, 0xB8, 0x14, 0xDE, 0x5E, 0x0B, 0xDB,
    0xE0, 0x32, 0x3A, 0x0A, 0x49, 0x06, 0x24, 0x5C, 0xC2, 0xD3, 0xAC, 0x62, 0x91, 0x95, 0xE4, 0x79,
    0xE7, 0xC8, 0x37, 0x6D, 0x8D, 0xD5, 0x4E, 0xA9, 0x6C, 0x56, 0xF4, 0xEA, 0x65, 0x7A, 0xAE, 0x08,
    0xBA, 0x78, 0x25, 0x2E, 0x1C, 0xA6, 0xB4, 0xC6, 0xE8, 0xDD, 0x74, 0x1F, 0x4B, 0xBD, 0x8B, 0x8A,
    0x70, 0x3E, 0xB5, 0x66, 0x48, 0x03, 0xF6, 0x0E, 0x61, 0x35, 0x57, 0xB9, 0x86, 0xC1, 0x1D, 0x9E,
    0xE1, 0xF8, 0x98, 0x11, 0x69, 0xD9, 0x8E, 0x94, 0x9B, 0x1E, 0x87, 0xE9, 0xCE, 0x55, 0x28, 0xDF,
    0x8C, 0xA1, 0x89, 0x0D, 0xBF, 0xE6, 0x42, 0x68, 0x41, 0x99, 0x2D, 0x0F, 0xB0, 0x54, 0xBB, 0x16,
)

ISBOX_GOLDEN = (
    0x52, 0x09, 0x6A, 0xD5, 0x30, 0x36, 0xA5, 0x38, 0xBF, 0x40, 0xA3, 0x9E, 0x81, 0xF3, 0xD7, 0xFB,
    0x7C, 0xE3, 0x39, 0x82, 0x9B, 0x2F, 0xFF, 0x87, 0x34, 0x8E, 0x43, 0x44, 0xC4, 0xDE, 0xE9, 0xCB,
    0x54, 0x7B, 0x94, 0x32, 0xA6, 0xC2, 0x23, 0x3D, 0xEE, 0x4C, 0x95, 0x0B, 0x42, 0xFA, 0xC3, 0x4E,
    0x08, 0x2E, 0xA1, 0x66, 0x28, 0xD9, 0x24, 0xB2, 0x76, 0x5B, 0xA2, 0x49, 0x6D, 0x8B, 0xD1, 0x25,
    0x72, 0xF8, 0xF6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xD4, 0xA4, 0x5C, 0xCC, 0x5D, 0x65, 0xB6, 0x92,
    0x6C, 0x70, 0x48, 0x50, 0xFD, 0xED, 0xB9, 0xDA, 0x5E, 0x15, 0x46, 0x57, 0xA7, 0x8D, 0x9D, 0x84,
    0x90, 0xD8, 0xAB, 0x00, 0x8C, 0xBC, 0xD3, 0x0A, 0xF7, 0xE4, 0x58, 0x05, 0xB8, 0xB3, 0x45, 0x06,
    0xD0, 0x2C, 0x1E, 0x8F, 0xCA, 0x3F, 0x0F, 0x02, 0xC1, 0xAF, 0xBD, 0x03, 0x01, 0x13, 0x8A, 0x6B,
    0x3A, 0x91, 0x11, 0x41, 0x4F, 0x67, 0xDC, 0xEA, 0x97, 0xF2, 0xCF, 0xCE, 0xF0, 0xB4, 0xE6, 0x73,
    0x96, 0xAC, 0x74, 0x22, 0xE7, 0xAD, 0x35, 0x85, 0xE2, 0xF9, 0x37, 0xE8, 0x1C, 0x75, 0xDF, 0x6E,
    0x47, 0xF1, 0x1A, 0x71, 0x1D, 0x29, 0xC5, 0x89, 0x6F, 0xB7, 0x62, 0x0E, 0xAA, 0x18, 0xBE, 0x1B,
    0xFC, 0x56, 0x3E, 0x4B, 0xC6, 0xD2, 0x79, 0x20, 0x9A, 0xDB, 0xC0, 0xFE, 0x78, 0xCD, 0x5A, 0xF4,
    0x1F, 0xDD, 0xA8, 0x33, 0x88, 0x07, 0xC7, 0x31, 0xB1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xEC, 0x5F,
    0x60, 0x51, 0x7F, 0xA9, 0x19, 0xB5, 0x4A, 0x0D, 0x2D, 0xE5, 0x7A, 0x9F, 0x93, 0xC9, 0x9C, 0xEF,
    0xA0, 0xE0, 0x3B, 0x4D, 0xAE, 0x2A, 0xF5, 0xB0, 0xC8, 0xEB, 0xBB, 0x3C, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2B, 0x04, 0x7E, 0xBA, 0x77, 0xD6, 0x26, 0xE1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0C, 0x7D,
)


class TestSbox(unittest.TestCase):
    def test_canright_sbox(self):
        sbox = CanrightSbox()
        for value, golden in enumerate(SBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(sbox.cal_sbox(value), golden)

    def test_canright_isbox(self):
        sbox = CanrightSbox()
        for value, golden in enumerate(ISBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(sbox.cal_isbox(value), golden)

    def test_tower_inverse(self):
        sbox = TowerSbox()
        golden = [0x0, 0x4, 0xC, 0x8, 0x1, 0xA, 0xE, 0xD, 0x3, 0xB, 0x5, 0x9, 0x2, 0x7, 0x6, 0xF]
        for x in range(16):
            with self.subTest(value=f"0x{x:02x}"):
                i = sbox.g4_inverse(x)
                self.assertEqual(i, golden[x], f"{x}")

    def test_tower_sbox(self):
        sbox = TowerSbox()
        for value, golden in enumerate(SBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(sbox.cal_sbox(value), golden)

    @unittest.skip("TowerSbox not implemented yet")
    def test_tower_isbox(self):
        sbox = TowerSbox()
        for value, golden in enumerate(ISBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(sbox.cal_isbox(value), golden)


if __name__ == "__main__":
    unittest.main()
