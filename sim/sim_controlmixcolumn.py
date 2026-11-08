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
    assert dut.done.value == 0
    await Timer(1, unit="ns")
    dut.rst_n.value = 1


async def trigger(dut, r_dec):
    dut.r_dec.value = r_dec
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.start.value = 0


async def observe_pulses(dut, cycles):
    pulses = []
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        pulses.append((int(dut.c_mixcol.value), int(dut.done.value)))
    return pulses


@cocotb.test()
async def test_encrypt_generates_four_mixcolumn_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0)
    assert await observe_pulses(dut, 6) == [
        (1, 0),
        (1, 1),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
    ]


@cocotb.test()
async def test_decrypt_generates_twelve_mixcolumn_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=1)
    assert await observe_pulses(dut, 14) == (
        [(1, 0)] * 9 + [(1, 1)] + [(0, 0)] * 4
    )


@cocotb.test()
async def test_start_pulse_runs_once(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0)
    assert await observe_pulses(dut, 7) == [
        (1, 0),
        (1, 1),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
        (0, 0),
    ]
