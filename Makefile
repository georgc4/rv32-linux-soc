IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys
CC ?= cc
PYTHON ?= python3
RISCV_AS ?= riscv64-unknown-elf-as
RISCV_LD ?= riscv64-unknown-elf-ld
RISCV_OBJCOPY ?= riscv64-unknown-elf-objcopy

.PHONY: test test-core test-digit lint synth-bus synth-core regen-smoke clean
test:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s physical_bus_tb -o build/physical_bus_tb rtl/interconnect/physical_bus.v sim/models/latency_device.v sim/tests/physical_bus_tb.v
	$(VVP) build/physical_bus_tb

test-core:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s rv32i_core_tb -o build/rv32i_core_tb rtl/cpu/rv32i_core.v rtl/interconnect/cpu_bus_adapter.v rtl/interconnect/physical_bus.v sim/models/word_ram.v sim/models/mmio_uart_sink.v sim/tests/rv32i_core_tb.v
	$(VVP) build/rv32i_core_tb

test-digit:
	mkdir -p build
	$(CC) -std=c11 -O2 -Wall -Wextra -Werror -o build/digit_demo software/digit/digit_demo.c
	$(PYTHON) software/digit/test_digit.py

lint:
	$(VERILATOR) --lint-only -Wall --top-module physical_bus rtl/interconnect/physical_bus.v
	$(VERILATOR) --lint-only -Wall --top-module rv32i_core rtl/cpu/rv32i_core.v
	$(VERILATOR) --lint-only -Wall --top-module cpu_bus_adapter rtl/interconnect/cpu_bus_adapter.v

regen-smoke:
	mkdir -p build
	$(RISCV_AS) -march=rv32i -mabi=ilp32 -o build/rv32i_smoke.o sim/programs/rv32i_smoke.S
	$(RISCV_LD) -m elf32lriscv --no-relax -Ttext=0x80000000 -o build/rv32i_smoke.elf build/rv32i_smoke.o
	$(RISCV_OBJCOPY) -O binary build/rv32i_smoke.elf build/rv32i_smoke.bin
	$(PYTHON) scripts/bin_to_memh.py build/rv32i_smoke.bin sim/programs/rv32i_smoke.hex

synth-bus:
	mkdir -p build
	$(YOSYS) -Q -T -p 'read_verilog rtl/interconnect/physical_bus.v; hierarchy -top physical_bus; proc; opt; synth -top physical_bus; stat' > build/synth-bus.log
	tail -25 build/synth-bus.log

synth-core:
	mkdir -p build
	$(YOSYS) -Q -T -p 'read_verilog rtl/cpu/rv32i_core.v; hierarchy -top rv32i_core; proc; opt; synth -top rv32i_core; stat' > build/synth-core.log
	tail -30 build/synth-core.log

clean:
	rm -rf build
