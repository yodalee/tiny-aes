import sys
from pathlib import Path

import cocotb
from cocotb.triggers import Timer

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from src.model.sbox import ISBOX_GOLDEN, SBOX_GOLDEN


def as_int(value):
    if hasattr(value, "to_unsigned"):
        return value.to_unsigned()
    return value.integer


async def check_value(dut, inv, value, expected):
    dut.c_inv.value = inv
    dut.i_data.value = value
    await Timer(1, unit="ns")
    actual = as_int(dut.o_data.value)
    assert actual == expected, (
        f"Sbox(c_inv={inv}, i_data=0x{value:02x}) returned "
        f"0x{actual:02x}, expected 0x{expected:02x}"
    )


@cocotb.test()
async def test_sbox_all_values(dut):
    for value, expected in enumerate(SBOX_GOLDEN):
        await check_value(dut, 0, value, expected)


@cocotb.test()
async def test_isbox_all_values(dut):
    for value, expected in enumerate(ISBOX_GOLDEN):
        await check_value(dut, 1, value, expected)
