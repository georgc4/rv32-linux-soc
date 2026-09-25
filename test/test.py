"""Tiny Tapeout interface reset smoke test for RTL and gate-level builds."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def reset_pins(dut):
    dut.ena.value = 1
    dut.ui_in.value = 1  # UART RX idle high
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 50, unit="ns").start())
    await ClockCycles(dut.clk, 10)
    assert (int(dut.uo_out.value) >> 1) & 0x1F == 0x1F  # chip selects
    assert (int(dut.uo_out.value) >> 6) & 1 == 1  # UART idle
    assert int(dut.uo_out.value) & 1 == 0  # SCK idle
    assert int(dut.uio_oe.value) == 0  # serial bus released in reset
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)
