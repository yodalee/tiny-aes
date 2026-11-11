import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.is_ke2.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert controls(dut) == (0, 0, 0, 0, 0)
    await Timer(1, unit="ns")
    dut.rst_n.value = 1


def controls(dut):
    return (
        int(dut.c_ke0.value),
        int(dut.c_ke1.value),
        int(dut.c_ke2.value),
        int(dut.busy.value),
        int(dut.done.value),
    )


async def trigger(dut, is_ke2):
    dut.is_ke2.value = is_ke2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    await Timer(1, unit="ns")
    dut.start.value = 0


async def observe_controls(dut, cycles):
    observed = []
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        observed.append(controls(dut))
    return observed


@cocotb.test()
async def test_ke0_then_three_ke1_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, is_ke2=0)
    assert controls(dut) == (1, 0, 0, 1, 0)
    assert await observe_controls(dut, 4) == [
        (0, 1, 0, 1, 0),
        (0, 1, 0, 1, 0),
        (0, 1, 0, 1, 1),
        (0, 0, 0, 0, 0),
    ]


@cocotb.test()
async def test_four_ke2_cycles(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, is_ke2=1)
    assert controls(dut) == (0, 0, 1, 1, 0)
    assert await observe_controls(dut, 4) == [
        (0, 0, 1, 1, 0),
        (0, 0, 1, 1, 0),
        (0, 0, 1, 1, 1),
        (0, 0, 0, 0, 0),
    ]


@cocotb.test()
async def test_start_is_ignored_while_busy(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, is_ke2=0)
    dut.is_ke2.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert controls(dut) == (0, 1, 0, 1, 0)
    await Timer(1, unit="ns")
    dut.start.value = 0
    assert await observe_controls(dut, 3) == [
        (0, 1, 0, 1, 0),
        (0, 1, 0, 1, 1),
        (0, 0, 0, 0, 0),
    ]
