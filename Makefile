IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys
CC ?= cc
PYTHON ?= python3

.PHONY: test test-digit lint synth-bus clean
test:
	mkdir -p build
	$(IVERILOG) -g2012 -Wall -s physical_bus_tb -o build/physical_bus_tb rtl/interconnect/physical_bus.v sim/models/latency_device.v sim/tests/physical_bus_tb.v
	$(VVP) build/physical_bus_tb

test-digit:
	mkdir -p build
	$(CC) -std=c11 -O2 -Wall -Wextra -Werror -o build/digit_demo software/digit/digit_demo.c
	$(PYTHON) software/digit/test_digit.py

lint:
	$(VERILATOR) --lint-only -Wall --top-module physical_bus rtl/interconnect/physical_bus.v

synth-bus:
	mkdir -p build
	$(YOSYS) -Q -T -p 'read_verilog rtl/interconnect/physical_bus.v; hierarchy -top physical_bus; proc; opt; synth -top physical_bus; stat' > build/synth-bus.log
	tail -25 build/synth-bus.log

clean:
	rm -rf build
