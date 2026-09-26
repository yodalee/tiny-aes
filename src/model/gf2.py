import galois
import numpy as np
import unittest

# based on the paper
# y = d = 0xFF, y ** 16 = 0xFE for GF(256)/GF(16)
# z = alpha^2 = 0x5C, z ** 4 = 0x5D for GF(16)/GF(4)
# w = omega = 0xBD, w ** 2 = 0xBC for GF(4)/GF(2)

class TestCanright(unittest.TestCase):
    def setUp(self):
        self.GF2 = galois.GF2
        self.GF256 = galois.GF(2**8, irreducible_poly = [1, 0, 0, 0, 1, 1, 0, 1, 1])

        self.y = self.GF256(0xFF)
        self.z = self.GF256(0x5C)
        self.w = self.GF256(0xBD)
        self.y16 = self.y ** 16
        self.z4 = self.z ** 4
        self.w2 = self.w ** 2

        # the affine matrix of S
        self.S = [0x8F, 0xC7, 0xE3, 0xF1, 0xF8, 0x7C, 0x3E, 0x1F]
        # Golden value from c code
        self.X2A = [0x64, 0x78, 0x6E, 0x8C, 0x68, 0x29, 0xDE, 0x60]
        self.A2X = [0x98, 0xF3, 0xF2, 0x48, 0x09, 0x81, 0xA9, 0xFF]
        self.X2S = [0x58, 0x2D, 0x9E, 0x0B, 0xDC, 0x04, 0x03, 0x24]
        self.S2X = [0x8C, 0x79, 0x05, 0xEB, 0x12, 0x04, 0x51, 0x53]

    def _toMat(self, l: list[int]) -> galois.GF2:
        lmat = [[] for _ in range(8)]
        for x in l:
            for row, bit in zip(lmat, bin(x)[2:].zfill(8)):
                row.append(int(bit))
        return self.GF2(lmat)

    def _toList(self, mat: galois.GF2) -> list[int]:
        l = []
        for col in range(mat.shape[1]):
            val = 0
            for row in range(mat.shape[0]):
                val = val * 2 + int(mat[row, col])
            l.append(val)
        return l


    def test_basis(self):
        self.assertEqual(self.y16, self.GF256(0xFE))
        self.assertEqual(self.z4, self.GF256(0x5D))
        self.assertEqual(self.w2, self.GF256(0xBC))

    def test_levels_linkage(self):
        nu = self.GF256(0xEC)
        N = self.GF256(0xBC)
        self.assertEqual(nu, N * N * self.z)
        omega = self.GF256(0xBD)
        self.assertEqual(N, omega * omega)
        self.assertEqual(N * N, omega)


    def test_X2A(self):
        # The X2A transformation from b to g is defined as:
        # b = [b7, b6, b5, b4, b3, b2, b1, b0]
        # g = (y16 * (Z4 * (w2 * b7 + w * b6) + z * ( w2 * b5 + w * b4))
        #   + (y   * (Z4 * (w2 * b3 + w * b2) + z * ( w2 * b1 + w * b0)))
        # Thus A2X = [
        #   y16 * Z4 * w2, y16 * Z4 * w, y16 * z * w2, y16 * z * w,
        #   y   * Z4 * w2, y   * Z4 * w, y +   z * w2, y   * z * w
        X2A = [
            self.y16 * self.z4 * self.w2,
            self.y16 * self.z4 * self.w,
            self.y16 * self.z * self.w2,
            self.y16 * self.z * self.w,
            self.y   * self.z4 * self.w2,
            self.y   * self.z4 * self.w,
            self.y   * self.z * self.w2,
            self.y   * self.z * self.w
        ]
        self.assertEqual(X2A, self.X2A)

    def test_A2X(self):
        # The A2X transformation from g to b is defined as:
        # g = (y16 * (Z4 * (w2 * b7 + w * b6) + z * ( w2 * b5 + w * b4))
        #   + (y   * (Z4 * (w2 * b3 + w * b2) + z * ( w2 * b1 + w * b0)))
        # Thus A2X = [
        #   y16 * Z4 * w2, y16 * Z4 * w, y16 * z * w2, y16 * z * w,
        #   y   * Z4 * w2, y   * Z4 * w, y +   z * w2, y   * z * w
        # golden = [0x98, 0xF3, 0xF2, 0x48, 0x09, 0x81, 0xA9, 0xFF]
        matX2A = self._toMat(self.X2A)
        matA2X = np.linalg.inv(matX2A)
        l = self._toList(matA2X)
        self.assertEqual(l, self.A2X)

    def test_X2S(self):
        # The X2S transformation is an X2A transformation followed by an affine transformation S
        matX2A = self._toMat(self.X2A)
        matA2S = self._toMat(self.S)
        matX2S = np.linalg.matmul(matA2S, matX2A)
        l = self._toList(matX2S)
        self.assertEqual(l, self.X2S)

    def test_S2X(self):
        # The X2S transformation is an X2A transformation followed by an affine transformation S
        matA2X = self._toMat(self.A2X)
        matA2S = self._toMat(self.S)
        matS2A = np.linalg.inv(matA2S)
        matS2X = np.linalg.matmul(matA2X, matS2A)
        l = self._toList(matS2X)
        self.assertEqual(l, self.S2X)

if __name__ == "__main__":
    unittest.main()