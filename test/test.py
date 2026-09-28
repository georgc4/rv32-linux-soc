"""Tiny Tapeout interface reset smoke test for RTL and gate-level builds."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


@cocotb.test()
async def reset_pins(dut):
    dut.ena.value = 1
    dut.ui_in.value = 1 << 3  # UART RX idle high on ui_in[3]
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 50, unit="ns").start())
    await ClockCycles(dut.clk, 10)
    await Timer(1, unit="ns")  # allow gate-level propagation after the clock edge
    assert int(dut.uo_out.value) & 0x6E == 0x6E  # CS# on uo[1:3], uo[5:6]
    assert (int(dut.uo_out.value) >> 4) & 1 == 1  # UART TX idle on uo_out[4]
    assert int(dut.uo_out.value) & 1 == 0  # SCK idle
    assert int(dut.uio_oe.value) == 0  # serial bus released in reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
