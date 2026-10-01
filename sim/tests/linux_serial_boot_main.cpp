#include "Vlinux_serial_boot_tb.h"
#include "verilated.h"

#include <algorithm>
#include <memory>

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> context{new VerilatedContext};
    context->threads(1);
    context->commandArgs(argc, argv);
    const std::unique_ptr<Vlinux_serial_boot_tb> top{
        new Vlinux_serial_boot_tb{context.get(), ""}};

    // 20 MHz core clock, 1 ps simulation precision. Visit every timed event,
    // including flash preload at 1 ns and chip output/release delays of 2–7 ns.
    // Jumping only between clock edges skips events in a --timing model.
    constexpr uint64_t half_period_ps = 25000;
    uint64_t next_clock = half_period_ps;
    top->clk = 0;
    top->eval();
    while (!context->gotFinish()) {
        uint64_t next = next_clock;
        if (top->eventsPending()) next = std::min(next, top->nextTimeSlot());
        context->time(next);
        if (next == next_clock) {
            top->clk = !top->clk;
            next_clock += half_period_ps;
        }
        top->eval();
    }
    top->final();
    context->statsPrintSummary();
    return 0;
}
