import unittest
from sbox import SBOX_GOLDEN, ISBOX_GOLDEN

class ArishSbox:
    # New Area Record for the AES Combined S-Box/Inverse S-Box June 2018
    # DOI:10.1109/ARITH.2018.8464780
    # Conference: 2018 IEEE 25th Symposium on Computer Arithmetic (ARITH)
    def cal_sbox(self, i: int) -> int:
        return i

    def cal_isbox(self, i: int) -> int:
        return 255-i

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
