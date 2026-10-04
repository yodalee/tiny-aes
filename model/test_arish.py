import unittest
from sbox import SBOX_GOLDEN, ISBOX_GOLDEN

class ArishSbox:
    # New Area Record for the AES Combined S-Box/Inverse S-Box June 2018
    # DOI:10.1109/ARITH.2018.8464780
    # Conference: 2018 IEEE 25th Symposium on Computer Arithmetic (ARITH)
    A2X = [0x64, 0xF3, 0xF1, 0x84, 0x06, 0x42, 0x56, 0xFF]
    X2S = [0x2D, 0x58, 0x0B, 0x9E, 0x04, 0xDC, 0x24, 0x03]
    S2X = [0x4C, 0xB6, 0x0A, 0xD7, 0x21, 0x08, 0xA2, 0xA3]
    X2A = [0x78, 0x64, 0x8C, 0x6E, 0x29, 0x68, 0x60, 0xDE]
    ETA = 0b01

    def rebase(self, n:int, base: list[int]) -> int:
        ret = 0
        for offset in range(7, -1, -1):
            if n & 1 == 1:
                ret ^= base[offset]
            n >>= 1
        return ret

    # ============================================================
    # GF(2^2) normal basis
    # x = x1*w + x0*w^2 where w^2 + w + 1 = 0
    # In bit representation
    #     [00] = 0
    #     [01] = w^2
    #     [10] = w
    #     [11] = 1
    # ============================================================

    def g4_mul(self, a, b):
        """
        Normal-basis multiplication in GF(2^2).
        """
        a1 = (a >> 1) & 1
        a0 = a & 1
        b1 = (b >> 1) & 1
        b0 = b & 1

        # Apply w^2 = w + 1
        # [a1, a0] = (a1+a0)*w + a0
        ap1 = a1 ^ a0
        ap0 = a0
        bp1 = b1 ^ b0
        bp0 = b0

        # polynomial multiplication
        # modulo w^2 + w + 1

        cp0 = (ap0 & bp0) ^ (ap1 & bp1)
        cp1 = (ap1 & bp0) ^ (ap0 & bp1) ^ (ap1 & bp1)

        # convert back to normal basis
        #
        # cp1*w + cp0 = x1*w + x0*w^2, then
        # x0 = cp0
        # x1 = cp1 + cp0
        x0 = cp0
        x1 = cp1 ^ cp0
        return (x1 << 1) | x0


    # ============================================================
    # GF(2^4) normal basis
    #
    # x = X1*A + X0*A^4
    #
    # X1 = bits [3:2]
    # X0 = bits [1:0]
    #
    # A and A^4 are roots of
    #
    #     z^2 + z + eta, where eta = w^2 = 01
    # ============================================================

    def g16_mul(self, a, b):
        A1 = (a >> 2) & 0b11
        A0 = a & 0b11
        B1 = (b >> 2) & 0b11
        B0 = b & 0b11

        # Convert normal basis
        # With A^4 = A + 1
        # A1*A + A0*A^4  = (A1 + A0)*A + A0
        ap = A1 ^ A0
        aq = A0
        bp = B1 ^ B0
        bq = B0

        # multiply in polynomial basis:
        # A^2 = A + eta

        t = self.g4_mul(ap, bp)
        cp = t ^ self.g4_mul(ap, bq) ^ self.g4_mul(aq, bp)
        cq = self.g4_mul(self.ETA, t) ^ self.g4_mul(aq, bq)

        # Convert back:
        #
        # cp*A + cq = X1*A + X0*A^4
        # X0 = cq
        # X1 = cp + cq
        X0 = cq
        X1 = cp ^ cq
        return (X1 << 2) | X0


    def g16_square(self, a):
        return self.g16_mul(a, a)

    def g16_pow(self, a, n):
        # IMPORTANT:
        # 1 = A + A^4
        # and each coefficient "1" in GF(2^2)
        # is w + w^2 = 11
        # therefore GF(2^4) 1 = 1111
        r = 0b1111

        while n:
            if n & 1:
                r = self.g16_mul(r, a)
            a = self.g16_square(a)
            n >>= 1
        return r

    def g16_inv(self, a):
        if a == 0:
            return 0
        return self.g16_pow(a, 14)

    def g17(self, a: int, b: int) -> int:
        NU = 0b0010
        # Calculate the g to the power of 17
        # As g = AY + BY^16, g16 = BY + AY^16
        # g17 = (AxB)(Y + Y^16) + (A^2 + B^2)Y^17
        #   xince (Y + Y^16) = 1 and Y^17 = nu, so g17 = (AxB) + nu * (A+B)^2
        c = self.g16_mul(a, b)
        d = self.g16_square(a ^ b)
        d = self.g16_mul(NU, d)
        return c ^ d

    def g256_inverse(self, n: int) -> int:
        a = (n >> 4) & 0x0F
        b = n & 0xF
        d = self.g17(a, b)
        e = self.g16_inv(d)
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
        self.sbox = ArishSbox()

    def test_g17_inverse(self):
        golden = [0x0, 0x4, 0xC, 0x8, 0x1, 0xA, 0xE, 0xD, 0x3, 0xB, 0x5, 0x9, 0x2, 0x7, 0x6, 0xF]
        for x in range(16):
            with self.subTest(value=f"0x{x:02x}"):
                inv = self.sbox.g16_inv(x)
                self.assertEqual(inv, golden[x], f"{x}")

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
