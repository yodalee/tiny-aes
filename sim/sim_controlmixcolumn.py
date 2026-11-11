import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.r_dec.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert dut.c_mixcol.value == 0
    assert dut.busy.value == 0
    assert dut.done.value == 0
    await Timer(1, unit="ns")
    dut.rst_n.value = 1


async def trigger(dut, r_dec):
    dut.r_dec.value = r_dec
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    await Timer(1, unit="ns")
    dut.start.value = 0


async def observe_cycles(dut, cycles):
    pulses = []
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        pulses.append(
            (int(dut.c_mixcol.value), int(dut.busy.value), int(dut.done.value))
        )
    return pulses


@cocotb.test()
async def test_encrypt_generates_four_mixcolumn_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0)
    assert (int(dut.c_mixcol.value), int(dut.busy.value), int(dut.done.value)) == (
        1,
        1,
        0,
    )
    assert await observe_cycles(dut, 5) == [
        (1, 1, 0),
        (1, 1, 0),
        (1, 1, 1),
        (0, 0, 0),
        (0, 0, 0),
    ]


@cocotb.test()
async def test_decrypt_generates_twelve_mixcolumn_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=1)
    assert (int(dut.c_mixcol.value), int(dut.busy.value), int(dut.done.value)) == (
        1,
        1,
        0,
    )
    assert await observe_cycles(dut, 13) == (
        [(1, 1, 0)] * 10 + [(1, 1, 1), (0, 0, 0), (0, 0, 0)]
    )


@cocotb.test()
async def test_start_is_ignored_while_busy(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert (int(dut.c_mixcol.value), int(dut.busy.value), int(dut.done.value)) == (
        1,
        1,
        0,
    )
    await Timer(1, unit="ns")
    dut.start.value = 0
    assert await observe_cycles(dut, 4) == [
        (1, 1, 0),
        (1, 1, 1),
        (0, 0, 0),
        (0, 0, 0),
    ]
