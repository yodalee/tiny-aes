import galois
import numpy as np
import unittest

def cal_sbox(i: int) -> int:
    return i

def cal_isbox(i: int) -> int:
    return 255-i

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