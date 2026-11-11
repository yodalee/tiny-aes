import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


def controls(dut):
    return (
        int(dut.c_add.value),
        int(dut.c_sbox.value),
        int(dut.c_kxor.value),
        int(dut.c_ikxor.value),
        int(dut.busy.value),
        int(dut.done.value),
    )


async def reset(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.r_dec.value = 0
    dut.i_sbox.value = 0
    dut.i_xor.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert controls(dut) == (0, 0, 0, 0, 0, 0)
    assert (int(dut.o_sbox.value), int(dut.o_xor.value)) == (0, 0)
    await Timer(1, unit="ns")
    dut.rst_n.value = 1


async def trigger(dut, *, r_dec, i_sbox, i_xor):
    dut.r_dec.value = r_dec
    dut.i_sbox.value = i_sbox
    dut.i_xor.value = i_xor
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    await Timer(1, unit="ns")
    dut.start.value = 0


async def observe(dut, cycles):
    values = []
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        values.append(controls(dut))
    return values


@cocotb.test()
async def test_encrypt_sbox_and_full_kxor(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0, i_sbox=1, i_xor=0b11)
    assert controls(dut) == (1, 1, 1, 0, 1, 0)
    assert (int(dut.o_sbox.value), int(dut.o_xor.value)) == (1, 3)
    assert await observe(dut, 8) == [
        (1, 1, 1, 0, 1, 0),
        (1, 1, 1, 0, 1, 0),
        (1, 1, 1, 0, 1, 0),
        (1, 1, 1, 0, 1, 0),
        (1, 1, 1, 0, 1, 0),
        (1, 1, 1, 0, 1, 0),
        (1, 1, 1, 0, 1, 1),
        (0, 0, 0, 0, 0, 0),
    ]


@cocotb.test()
async def test_xor_window_and_decrypt_ikxor(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0, i_sbox=0, i_xor=0b10)
    assert [value[2] for value in [controls(dut)] + await observe(dut, 7)] == [
        1,
        1,
        1,
        1,
        0,
        0,
        0,
        0,
    ]

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    await trigger(dut, r_dec=1, i_sbox=0, i_xor=0b01)
    assert [value[3] for value in [controls(dut)] + await observe(dut, 7)] == [
        0,
        0,
        0,
        0,
        1,
        1,
        1,
        1,
    ]
    assert all(value[2] == 0 for value in [controls(dut)])


@cocotb.test()
async def test_start_is_ignored_while_busy_and_request_is_latched(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0, i_sbox=1, i_xor=0b10)
    dut.r_dec.value = 1
    dut.i_sbox.value = 0
    dut.i_xor.value = 0b01
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert controls(dut) == (1, 1, 1, 0, 1, 0)
    assert (int(dut.o_sbox.value), int(dut.o_xor.value)) == (1, 2)
    await Timer(1, unit="ns")
    dut.start.value = 0
