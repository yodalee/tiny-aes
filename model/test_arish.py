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

    def rebase(self, n:int, base: list[int]) -> int:
        ret = 0
        for offset in range(7, -1, -1):
            if n & 1 == 1:
                ret ^= base[offset]
            n >>= 1
        return ret

    def g256_inverse(self, n: int) -> int:
        a = (n >> 4) & 0x0F
        b = n & 0xF
        p = a
        q = b
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

    @unittest.skip("Sbox is not implemented yet")
    def test_sbox_matches_golden_for_every_byte(self):
        for value, golden in enumerate(SBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(self.sbox.cal_sbox(value), golden)

    @unittest.skip("Isbox is not implemented yet")
    def test_isbox_matches_golden_for_every_byte(self):
        for value, golden in enumerate(ISBOX_GOLDEN):
            with self.subTest(value=f"0x{value:02x}"):
                self.assertEqual(self.sbox.cal_isbox(value), golden)


if __name__ == "__main__":
    unittest.main()
