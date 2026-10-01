"""Boot through real serial pins against datasheet models, RTL and gate netlist.

The GL action uses unit cell delays, not extracted SDF timing. STA remains the
route timing gate. No DUT internal force, diagnostic parameter or ROM override.
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, with_timeout


async def receive_uart(dut):
    # Poll a dedicated output bit; the other uo_out bits are the memory bus.
    while (int(dut.uo_out.value) >> 4) & 1:
        await Timer(50, unit="ns")
    await Timer(4400, unit="ns")  # middle of start bit, divisor 11 * 16 clocks
    assert ((int(dut.uo_out.value) >> 4) & 1) == 0
    value = 0
    for bit in range(8):
        await Timer(8800, unit="ns")
        value |= ((int(dut.uo_out.value) >> 4) & 1) << bit
    await Timer(8800, unit="ns")
    assert ((int(dut.uo_out.value) >> 4) & 1) == 1, "UART stop bit"
    return value


@cocotb.test()
async def boot_through_serial_memories(dut):
    dut.ena.value = 1
    dut.ui_in.value = 1 << 3
    dut.rst_n.value = 0
    cocotb.start_soon(Clock(dut.clk, 50, unit="ns").start())
    await ClockCycles(dut.clk, 10)
    await Timer(10, unit="ns")
    assert int(dut.uo_out.value) & 0x6E == 0x6E
    assert (int(dut.uo_out.value) >> 4) & 1 == 1
    assert int(dut.uo_out.value) & 1 == 0
    assert int(dut.uio_oe.value) == 0
    dut.rst_n.value = 1
    received = bytes([await with_timeout(receive_uart(dut), 6, "ms") for _ in range(3)])
    assert received == b"OK\n", received
    assert int(dut.signature.value) == 0x5A5AA5A5
    assert int(dut.uo_out.value) & 0x80, "memory initialization did not finish"
    # Reboot with a corrupt checksum: the immutable ROM must reject it.
    dut.rst_n.value = 0
    dut.corrupt_image.value = 1
    await ClockCycles(dut.clk, 10)
    await Timer(10, unit="ns")
    dut.rst_n.value = 1
    rejected = await with_timeout(receive_uart(dut), 6, "ms")
    assert rejected == ord("E"), rejected
