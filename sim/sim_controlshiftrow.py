import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.r_dec.value = 0
    dut.i_valid.value = 0
    await RisingEdge(dut.clk)
    await ReadOnly()
    assert controls(dut) == (0, 0, 0, 0, 0)
    assert dut.o_valid.value == 0
    await Timer(1, unit="ns")
    dut.rst_n.value = 1


def controls(dut):
    return (
        int(dut.c_srow0.value),
        int(dut.c_srow1.value),
        int(dut.c_srow2.value),
        int(dut.c_isrow0.value),
        int(dut.c_isrow1.value),
    )


async def trigger(dut, r_dec):
    dut.r_dec.value = r_dec
    dut.i_valid.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.i_valid.value = 0


async def observe_controls(dut, cycles):
    observed = []
    for _ in range(cycles):
        await RisingEdge(dut.clk)
        await ReadOnly()
        observed.append((controls(dut), int(dut.o_valid.value)))
    return observed


@cocotb.test()
async def test_encrypt_generates_shiftrow_sequence(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=0)
    assert await observe_controls(dut, 4) == [
        ((1, 0, 0, 0, 0), 0),
        ((0, 1, 0, 0, 0), 0),
        ((0, 0, 1, 0, 0), 1),
        ((0, 0, 0, 0, 0), 0),
    ]


@cocotb.test()
async def test_decrypt_generates_inverse_shiftrow_sequence(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    await trigger(dut, r_dec=1)
    assert await observe_controls(dut, 4) == [
        ((1, 0, 0, 0, 0), 0),
        ((0, 0, 0, 1, 0), 0),
        ((0, 0, 0, 0, 1), 1),
        ((0, 0, 0, 0, 0), 0),
    ]


@cocotb.test()
async def test_held_valid_does_not_restart_shiftrow_sequence(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    dut.i_valid.value = 1
    assert await observe_controls(dut, 6) == [
        ((0, 0, 0, 0, 0), 0),
        ((1, 0, 0, 0, 0), 0),
        ((0, 1, 0, 0, 0), 0),
        ((0, 0, 1, 0, 0), 1),
        ((0, 0, 0, 0, 0), 0),
        ((0, 0, 0, 0, 0), 0),
    ]
