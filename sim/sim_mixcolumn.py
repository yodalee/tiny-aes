from pathlib import Path

import cocotb
from cocotb.triggers import Timer


def pack_bytes(values):
    value = 0
    for index, byte in enumerate(values):
        value |= byte << (8 * index)
    return value


async def check_mixcolumn(dut, input_bytes, expected_bytes):
    expected = pack_bytes(expected_bytes)
    dut.i_data.value = pack_bytes(input_bytes)
    await Timer(1, units="ns")
    actual = dut.o_data.value.integer
    assert actual == expected, (
        f"MixColumn({input_bytes!r}) returned 0x{actual:08x}, "
        f"expected 0x{expected:08x}"
    )


@cocotb.test()
async def test_mixcolumn_wiki1(dut):
    await check_mixcolumn(dut, [0x63, 0x47, 0xA2, 0xF0], [0x5D, 0xE0, 0x70, 0xBB])


@cocotb.test()
async def test_mixcolumn_wiki2(dut):
    await check_mixcolumn(dut, [0xF2, 0x0A, 0x22, 0x5C], [0x9F, 0xDC, 0x58, 0x9D])


@cocotb.test()
async def test_mixcolumn_wiki3(dut):
    await check_mixcolumn(dut, [0x01, 0x01, 0x01, 0x01], [0x01, 0x01, 0x01, 0x01])


@cocotb.test()
async def test_mixcolumn_wiki4(dut):
    await check_mixcolumn(dut, [0xC6, 0xC6, 0xC6, 0xC6], [0xC6, 0xC6, 0xC6, 0xC6])


@cocotb.test()
async def test_mixcolumn_wiki5(dut):
    await check_mixcolumn(dut, [0xD4, 0xD4, 0xD4, 0xD5], [0xD5, 0xD5, 0xD7, 0xD6])


@cocotb.test()
async def test_mixcolumn_wiki6(dut):
    await check_mixcolumn(dut, [0x2D, 0x26, 0x31, 0x4C], [0x4D, 0x7E, 0xBD, 0xF8])

