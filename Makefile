IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys
CC ?= cc
PYTHON ?= python3
RISCV_AS ?= riscv64-unknown-elf-as
RISCV_LD ?= riscv64-unknown-elf-ld
RISCV_OBJCOPY ?= riscv64-unknown-elf-objcopy

.PHONY: test test-core test-mdu test-priv test-sv32 test-supervisor test-serial test-uart test-timer test-plic test-linux-handoff test-linux-serial-boot test-soc test-soc-bad test-digit lint synth-bus synth-core synth-soc synth-sky130 stage-sky26d rtl-diagrams experiment-chart regen-smoke regen-priv regen-supervisor regen-rom image-smoke image-linux image-linux-flash clean

rtl-diagrams:
	$(PYTHON) tt/generate_rtl_block_diagrams.py

experiment-chart:
	$(PYTHON) experiments/visualize.py

test:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s physical_bus_tb -o build/physical_bus_tb rtl/interconnect/physical_bus.v sim/models/latency_device.v sim/tests/physical_bus_tb.v
	$(VVP) build/physical_bus_tb

test-core:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s rv32i_core_tb -o build/rv32i_core_tb rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/interconnect/cpu_bus_adapter.v rtl/interconnect/physical_bus.v sim/models/word_ram.v sim/models/mmio_uart_sink.v sim/tests/rv32i_core_tb.v
	$(VVP) build/rv32i_core_tb

test-mdu:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s rv32_mdu_tb -o build/rv32_mdu_tb rtl/cpu/rv32_mdu.v sim/tests/rv32_mdu_tb.v
	$(VVP) build/rv32_mdu_tb

test-priv:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s priv_trap_tb -o build/priv_trap_tb rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v sim/tests/priv_trap_tb.v
	$(VVP) build/priv_trap_tb
	$(IVERILOG) -g2012 -Wall -s priv_mip_tb -o build/priv_mip_tb rtl/cpu/rv32_priv_unit.v sim/tests/priv_mip_tb.v
	$(VVP) build/priv_mip_tb

test-sv32:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s sv32_bus_adapter_tb -o build/sv32_bus_adapter_tb rtl/interconnect/sv32_bus_adapter.v sim/tests/sv32_bus_adapter_tb.v
	$(VVP) build/sv32_bus_adapter_tb

test-supervisor:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s sv32_supervisor_tb -o build/sv32_supervisor_tb rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/interconnect/sv32_bus_adapter.v sim/tests/sv32_supervisor_tb.v
	$(VVP) build/sv32_supervisor_tb

test-serial:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s serial_mem_bridge_tb -o build/serial_mem_bridge_tb rtl/memory/serial_mem_bridge.v sim/models/serial_spi_model.v sim/tests/serial_mem_bridge_tb.v
	$(VVP) build/serial_mem_bridge_tb

test-uart:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s uart16550_lite_tb -o build/uart16550_lite_tb rtl/peripherals/uart16550_lite.v sim/tests/uart16550_lite_tb.v
	$(VVP) build/uart16550_lite_tb

test-plic:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s plic_lite_tb -o build/plic_lite_tb rtl/peripherals/plic_lite.v sim/tests/plic_lite_tb.v
	$(VVP) build/plic_lite_tb

test-timer:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s clint_timer_tb -o build/clint_timer_tb rtl/peripherals/clint_timer.v sim/tests/clint_timer_tb.v
	$(VVP) build/clint_timer_tb

test-soc:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s soc_boot_tb -o build/soc_boot_tb rtl/soc/soc_top.v rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/interconnect/physical_bus.v rtl/interconnect/sv32_bus_adapter.v rtl/peripherals/boot_rom.v rtl/peripherals/clint_timer.v rtl/peripherals/uart16550_lite.v rtl/peripherals/plic_lite.v rtl/memory/serial_mem_bridge.v sim/models/serial_spi_model.v sim/tests/soc_boot_tb.v
	$(VVP) build/soc_boot_tb

test-soc-bad: test-soc
	$(VVP) build/soc_boot_tb +bad_image

test-digit:
	mkdir -p build
	$(CC) -std=c11 -O2 -Wall -Wextra -Werror -o build/digit_demo software/digit/digit_demo.c
	$(PYTHON) software/digit/test_digit.py

lint:
	$(VERILATOR) --lint-only -Wall --top-module physical_bus rtl/interconnect/physical_bus.v
	$(VERILATOR) --lint-only -Wall --top-module rv32i_core rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v
	$(VERILATOR) --lint-only -Wall --top-module cpu_bus_adapter rtl/interconnect/cpu_bus_adapter.v
	$(VERILATOR) --lint-only -Wall --top-module sv32_bus_adapter rtl/interconnect/sv32_bus_adapter.v
	$(VERILATOR) --lint-only -Wall --top-module serial_mem_bridge rtl/memory/serial_mem_bridge.v
	$(VERILATOR) --lint-only -Wall --top-module clint_timer rtl/peripherals/clint_timer.v
	$(VERILATOR) --lint-only -Wall --top-module boot_rom rtl/peripherals/boot_rom.v
	$(VERILATOR) --lint-only -Wall --top-module uart16550_lite rtl/peripherals/uart16550_lite.v
	$(VERILATOR) --lint-only -Wall --top-module plic_lite rtl/peripherals/plic_lite.v
	$(VERILATOR) --lint-only -Wall --top-module tt_um_rv32_linux_soc rtl/soc/tt_um_rv32_linux_soc.v rtl/soc/soc_top.v rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/interconnect/physical_bus.v rtl/interconnect/sv32_bus_adapter.v rtl/peripherals/boot_rom.v rtl/peripherals/clint_timer.v rtl/peripherals/uart16550_lite.v rtl/peripherals/plic_lite.v rtl/memory/serial_mem_bridge.v

regen-smoke:
	mkdir -p build
	$(RISCV_AS) -march=rv32ima -mabi=ilp32 -o build/rv32i_smoke.o sim/programs/rv32i_smoke.S
	$(RISCV_LD) -m elf32lriscv --no-relax -Ttext=0x80000000 -o build/rv32i_smoke.elf build/rv32i_smoke.o
	$(RISCV_OBJCOPY) -O binary build/rv32i_smoke.elf build/rv32i_smoke.bin
	$(PYTHON) scripts/bin_to_memh.py build/rv32i_smoke.bin sim/programs/rv32i_smoke.hex

regen-priv:
	mkdir -p build
	$(RISCV_AS) -march=rv32im_zicsr -mabi=ilp32 -o build/priv_trap.o sim/programs/priv_trap.S
	$(RISCV_LD) -m elf32lriscv --no-relax -Ttext=0x80000000 -o build/priv_trap.elf build/priv_trap.o
	$(RISCV_OBJCOPY) -O binary build/priv_trap.elf build/priv_trap.bin
	$(PYTHON) scripts/bin_to_memh.py build/priv_trap.bin sim/programs/priv_trap.hex

regen-supervisor:
	mkdir -p build
	$(RISCV_AS) -march=rv32ima_zicsr -mabi=ilp32 -o build/sv32_supervisor.o sim/programs/sv32_supervisor.S
	$(RISCV_LD) -m elf32lriscv --no-relax -Ttext=0x80000000 -o build/sv32_supervisor.elf build/sv32_supervisor.o
	$(RISCV_OBJCOPY) -O binary build/sv32_supervisor.elf build/sv32_supervisor.bin
	$(PYTHON) scripts/bin_to_memh.py build/sv32_supervisor.bin sim/programs/sv32_supervisor.hex

regen-rom:
	mkdir -p build
	$(RISCV_AS) -march=rv32i -mabi=ilp32 -o build/boot_rom.o firmware/boot_rom.S
	$(RISCV_LD) -m elf32lriscv --no-relax -Ttext=0x00000000 -o build/boot_rom.elf build/boot_rom.o
	$(RISCV_OBJCOPY) -O binary build/boot_rom.elf build/boot_rom.bin
	$(PYTHON) scripts/bin_to_memh.py build/boot_rom.bin firmware/boot_rom.hex

image-smoke: regen-smoke
	$(PYTHON) scripts/make_flash_image.py build/rv32i_smoke.bin build/rv32i_smoke.flash.bin

image-linux:
	./linux/build-image.sh

image-linux-flash: image-linux
	./scripts/build_linux_firmware.sh

test-linux-handoff: image-linux-flash
	$(RISCV_AS) -march=rv32ima_zicsr_zifencei -mabi=ilp32 -o build/linux_handoff_stub.o sim/programs/linux_handoff_stub.S
	$(RISCV_LD) -m elf32lriscv --no-relax -Ttext=0x80400000 -o build/linux_handoff_stub.elf build/linux_handoff_stub.o
	$(RISCV_OBJCOPY) -O binary build/linux_handoff_stub.elf build/linux_handoff_stub.bin
	$(PYTHON) scripts/pack_linux_flash.py build/firmware/linux_loader.bin build/linux_handoff_stub.bin build/linux/rv32-linux-soc.dtb build/linux_handoff_stub.flash.bin --trim
	$(PYTHON) -c 'from pathlib import Path; p=Path("build/linux_handoff_stub.flash.bin"); Path("build/linux_handoff_stub.flash.hex").write_text("".join(f"{b:02x}\n" for b in p.read_bytes().ljust(270336, b"\xff")))'
	$(IVERILOG) -g2012 -Wall -s linux_handoff_tb -o build/linux_handoff_tb rtl/soc/soc_top.v rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/interconnect/physical_bus.v rtl/interconnect/sv32_bus_adapter.v rtl/peripherals/boot_rom.v rtl/peripherals/clint_timer.v rtl/peripherals/uart16550_lite.v rtl/peripherals/plic_lite.v rtl/memory/serial_mem_bridge.v sim/models/serial_spi_model.v sim/tests/linux_handoff_tb.v
	$(VVP) build/linux_handoff_tb
	$(VVP) build/linux_handoff_tb +bad_dtb
	$(VVP) build/linux_handoff_tb +bad_kernel

# Slow full-image run through the production quad-capable SPI bridge and five chips.
test-linux-serial-boot: image-linux-flash
	$(PYTHON) scripts/flash_to_bytehex.py build/linux/flash.bin build/linux/flash.serial.hex
	$(VERILATOR) --binary --timing -O3 -j 4 -Wno-fatal -CFLAGS '-O3' --top-module linux_serial_boot_tb --Mdir build/obj_linux_serial sim/tests/linux_serial_boot_tb.v sim/models/serial_spi_model.v rtl/soc/soc_top.v rtl/cpu/rv32i_core.v rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/interconnect/physical_bus.v rtl/interconnect/sv32_bus_adapter.v rtl/peripherals/boot_rom.v rtl/peripherals/clint_timer.v rtl/peripherals/uart16550_lite.v rtl/peripherals/plic_lite.v rtl/memory/serial_mem_bridge.v
	build/obj_linux_serial/Vlinux_serial_boot_tb

synth-bus:
	mkdir -p build
	$(YOSYS) -Q -T -p 'read_verilog rtl/interconnect/physical_bus.v; hierarchy -top physical_bus; proc; opt; synth -top physical_bus; stat' > build/synth-bus.log
	tail -25 build/synth-bus.log

synth-core:
	mkdir -p build
	$(YOSYS) -Q -T -p 'read_verilog rtl/cpu/rv32_priv_unit.v rtl/cpu/rv32_mdu.v rtl/cpu/rv32i_core.v; hierarchy -top rv32i_core; proc; opt; synth -top rv32i_core; stat' > build/synth-core.log
	tail -30 build/synth-core.log

synth-soc:
	mkdir -p build
	$(YOSYS) -Q -T -p 'read_verilog rtl/cpu/*.v rtl/interconnect/*.v rtl/peripherals/*.v rtl/memory/*.v rtl/soc/*.v; hierarchy -top tt_um_rv32_linux_soc; proc; opt; synth -top tt_um_rv32_linux_soc; stat' > build/synth-soc.log
	tail -30 build/synth-soc.log

synth-sky130:
	bash tt/run_sky130_synth.sh

stage-sky26d:
	$(PYTHON) tt/stage_sky26d.py

clean:
	rm -rf build
