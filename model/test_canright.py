import unittest
from sbox import SBOX_GOLDEN, ISBOX_GOLDEN

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

class TestSbox(unittest.TestCase):
    def setUp(self):
        self.sbox = CanrightSbox()

    def test_sbox_matches_golden_for_every_byte(self):
        for value, golden in enumerate(SBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(self.sbox.cal_sbox(value), golden)

    def test_isbox_matches_golden_for_every_byte(self):
        for value, golden in enumerate(ISBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(self.sbox.cal_isbox(value), golden)


if __name__ == "__main__":
    unittest.main()
