#include "Vlinux_serial_boot_tb.h"
#include "verilated.h"

#include <memory>

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> context{new VerilatedContext};
    context->threads(1);
    context->commandArgs(argc, argv);
    const std::unique_ptr<Vlinux_serial_boot_tb> top{
        new Vlinux_serial_boot_tb{context.get(), ""}};

    top->clk = 0;
    top->eval();
    context->timeInc(1000);  // Run the testbench's #1 flash initialization.
    top->eval();
    context->timeInc(4000);  // First rising edge at 5 ns.
    top->clk = 1;
    top->eval();
    while (!context->gotFinish()) {
        context->timeInc(5000);  // 5 ns per half cycle, in 1 ps ticks.
        top->clk = !top->clk;
        top->eval();
    }

    top->final();
    context->statsPrintSummary();
    return 0;
}
