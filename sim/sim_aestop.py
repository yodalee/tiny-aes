"""End-to-end AES tests for the byte-streaming AesTop interface.

Each transaction sends the 16-byte input block first, followed by its key.
The tests are intentionally skipped until ControlFsm implements loading,
round processing, and output serialization.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


DATA = bytes.fromhex("00112233445566778899aabbccddeeff")
KEY_LEVEL = {16: 0b00, 24: 0b01, 32: 0b10}

# AES ECB results for DATA=00112233445566778899aabbccddeeff and the
# incrementing key of the corresponding length.  Decryption deliberately uses
# the same input block, so its expected values are the inverse transformations.
EXPECTED = {
    (False, 16): bytes.fromhex("69c4e0d86a7b0430d8cdb78070b4c55a"),
    (False, 24): bytes.fromhex("dda97ca4864cdfe06eaf70a0ec0d7191"),
    (False, 32): bytes.fromhex("8ea2b7ca516745bfeafc49904b496089"),
    (True, 16): bytes.fromhex("762a5ab50929189cefdb99434790aad8"),
    (True, 24): bytes.fromhex("3369eb82973635e9c2e96d687724c790"),
    (True, 32): bytes.fromhex("eab487e68ec92db4ac288a24757b0262"),
}


def as_int(value):
    return int(value)


async def reset(dut):
    dut.rst_n.value = 0
    dut.i_valid.value = 0
    dut.i_data.value = 0
    dut.o_ready.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)


async def send_byte(dut, value):
    dut.i_data.value = value
    dut.i_valid.value = 1
    while not as_int(dut.i_ready.value):
        await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_aes(dut, decrypt, key_bytes):
    dut.r_dec.value = int(decrypt)
    dut.r_level.value = KEY_LEVEL[len(key_bytes)]
    await reset(dut)

    for value in DATA + key_bytes:
        await send_byte(dut, value)
    dut.i_valid.value = 0

    actual = bytearray()
    for _ in range(16):
        for _ in range(1_000):
            if as_int(dut.o_valid.value):
                break
            await RisingEdge(dut.clk)
        else:
            raise AssertionError("AES output did not become valid")
        actual.append(as_int(dut.o_data.value))
        await RisingEdge(dut.clk)
    return bytes(actual)


async def check_aes(dut, decrypt, key_length):
    key = bytes(range(key_length))
    actual = await run_aes(dut, decrypt, key)
    expected = EXPECTED[(decrypt, key_length)]
    direction = "decrypt" if decrypt else "encrypt"
    assert actual == expected, (
        f"AES-{key_length * 8} {direction} returned {actual.hex()}, "
        f"expected {expected.hex()}"
    )


@cocotb.test(skip=True)
async def test_aes128_encrypt(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await check_aes(dut, decrypt=False, key_length=16)


@cocotb.test(skip=True)
async def test_aes192_encrypt(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await check_aes(dut, decrypt=False, key_length=24)


@cocotb.test(skip=True)
async def test_aes256_encrypt(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await check_aes(dut, decrypt=False, key_length=32)


@cocotb.test(skip=True)
async def test_aes128_decrypt(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await check_aes(dut, decrypt=True, key_length=16)


@cocotb.test(skip=True)
async def test_aes192_decrypt(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await check_aes(dut, decrypt=True, key_length=24)


@cocotb.test(skip=True)
async def test_aes256_decrypt(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await check_aes(dut, decrypt=True, key_length=32)
