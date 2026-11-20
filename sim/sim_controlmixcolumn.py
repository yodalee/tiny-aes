import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.r_dec.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.c_mixcol.value) == 0
    await Timer(1, unit="ns")
    dut.rst_n.value = 1


async def trigger(dut, r_dec):
    dut.r_dec.value = r_dec
    dut.start.value = 1
    await Timer(1, unit="ns")
    first_cycle = int(dut.c_mixcol.value)
    await RisingEdge(dut.clk)
    await ReadOnly()
    second_cycle = int(dut.c_mixcol.value)
    await Timer(1, unit="ns")
    dut.start.value = 0
    return first_cycle, second_cycle


async def observe_cycles(dut, cycles):
    pulses = []
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        pulses.append(int(dut.c_mixcol.value))
    return pulses


@cocotb.test()
async def test_encrypt_generates_four_mixcolumn_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    first, second = await trigger(dut, r_dec=0)
    assert first == 1
    assert [first, second] + await observe_cycles(dut, 3) == [1, 1, 1, 1, 0]


@cocotb.test()
async def test_decrypt_generates_twelve_mixcolumn_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    first, second = await trigger(dut, r_dec=1)
    assert first == 1
    assert [first, second] + await observe_cycles(dut, 11) == [1] * 12 + [0]


@cocotb.test()
async def test_start_is_ignored_while_active(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    first, second = await trigger(dut, r_dec=0)
    assert (first, second) == (1, 1)
    dut.start.value = 1
    await Timer(1, unit="ns")
    assert int(dut.c_mixcol.value) == 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert int(dut.c_mixcol.value) == 1
    await Timer(1, unit="ns")
    dut.start.value = 0
    assert await observe_cycles(dut, 3) == [1, 0, 0]
