`timescale 1ns/1ps
// Integrated RV32IMA SoC with Sv32, boot ROM, serial memories and MMIO.
module soc_top #(
    parameter integer PSRAM_POWERUP_CYCLES = 3000,
    parameter DIAGNOSTIC_MODE = 0
) (
    input wire clk, rst_n,
    input wire uart_rx,
    output wire uart_tx,
    output wire spi_sck,
    output wire [4:0] spi_cs_n,
    input wire [5:0] spi_dq_in,
    output wire [5:0] spi_dq_out,
    output wire [5:0] spi_dq_oe,
    output wire memory_initialized,
    output wire cpu_halted,
    output wire cpu_fault,
    output wire [31:0] cpu_fault_pc
);
    wire iv, ir, ix, iy, ie, ipf;
    wire [31:0] ia, id;
    wire dv, dr, dx, dy, de, dpf, dw;
    wire [31:0] da, dd, dq;
    wire [3:0] ds, bs;
    wire bv, br, bx, by, be, bw;
    wire [31:0] ba, bd, bq, va, vd;
    wire vw;
    wire [3:0] vs;
    wire [6:0] sv, sr, sx, sy, se;
    wire [31:0] rdata, fdata, udata, odata, tdata, cdata, pdata;
    wire uart_irq, plic_irq, timer_irq, software_irq;
    wire [63:0] time_value;
    wire [1:0] current_privilege;
    wire [31:0] current_satp, current_mstatus;
    wire retire_valid;
    wire sfence_commit;
    wire [31:0] retire_pc;

    rv32i_core #(.RESET_PC(32'h0000_0000),
                  .DIAGNOSTIC_MODE(DIAGNOSTIC_MODE)) cpu (
        .clk(clk), .rst_n(rst_n),
        .irq_timer(timer_irq), .irq_software(software_irq), .irq_external(uart_irq),
        .irq_supervisor_external(plic_irq),
        .time_value(time_value),
        .current_privilege(current_privilege), .current_satp(current_satp),
        .current_mstatus(current_mstatus), .sfence_commit(sfence_commit),
        .i_req_valid(iv), .i_req_ready(ir), .i_req_addr(ia),
        .i_resp_valid(ix), .i_resp_ready(iy), .i_resp_data(id),
        .i_resp_err(ie), .i_resp_page_fault(ipf),
        .d_req_valid(dv), .d_req_ready(dr), .d_req_addr(da),
        .d_req_write(dw), .d_req_wdata(dd), .d_req_wstrb(ds),
        .d_resp_valid(dx), .d_resp_ready(dy), .d_resp_data(dq),
        .d_resp_err(de), .d_resp_page_fault(dpf),
        .halted(cpu_halted), .fault(cpu_fault), .fault_pc(cpu_fault_pc),
        .retire_valid(retire_valid), .retire_pc(retire_pc)
    );
    sv32_bus_adapter adapter (
        .clk(clk), .rst_n(rst_n),
        .privilege(current_privilege), .satp(current_satp), .mstatus(current_mstatus),
        .tlb_flush(sfence_commit),
        .i_req_valid(iv), .i_req_ready(ir), .i_req_addr(ia),
        .i_resp_valid(ix), .i_resp_ready(iy), .i_resp_data(id),
        .i_resp_err(ie), .i_resp_page_fault(ipf),
        .d_req_valid(dv), .d_req_ready(dr), .d_req_addr(da),
        .d_req_write(dw), .d_req_wdata(dd), .d_req_wstrb(ds),
        .d_resp_valid(dx), .d_resp_ready(dy), .d_resp_data(dq),
        .d_resp_err(de), .d_resp_page_fault(dpf),
        .bus_req_valid(bv), .bus_req_ready(br), .bus_req_addr(ba),
        .bus_req_write(bw), .bus_req_wdata(bd), .bus_req_wstrb(bs),
        .bus_resp_valid(bx), .bus_resp_ready(by), .bus_resp_data(bq), .bus_resp_err(be)
    );
    physical_bus bus (
        .clk(clk), .rst_n(rst_n),
        .req_valid(bv), .req_ready(br), .req_addr(ba),
        .req_write(bw), .req_wdata(bd), .req_wstrb(bs),
        .resp_valid(bx), .resp_ready(by), .resp_rdata(bq), .resp_err(be),
        .dev_addr(va), .dev_write(vw), .dev_wdata(vd), .dev_wstrb(vs),
        .ram_req_valid(sv[0]), .ram_req_ready(sr[0]),
        .ram_resp_valid(sx[0]), .ram_resp_ready(sy[0]),
        .ram_resp_rdata(rdata), .ram_resp_err(se[0]),
        .flash_req_valid(sv[1]), .flash_req_ready(sr[1]),
        .flash_resp_valid(sx[1]), .flash_resp_ready(sy[1]),
        .flash_resp_rdata(fdata), .flash_resp_err(se[1]),
        .uart_req_valid(sv[2]), .uart_req_ready(sr[2]),
        .uart_resp_valid(sx[2]), .uart_resp_ready(sy[2]),
        .uart_resp_rdata(udata), .uart_resp_err(se[2]),
        .rom_req_valid(sv[3]), .rom_req_ready(sr[3]),
        .rom_resp_valid(sx[3]), .rom_resp_ready(sy[3]),
        .rom_resp_rdata(odata), .rom_resp_err(se[3]),
        .timer_req_valid(sv[4]), .timer_req_ready(sr[4]),
        .timer_resp_valid(sx[4]), .timer_resp_ready(sy[4]),
        .timer_resp_rdata(tdata), .timer_resp_err(se[4]),
        .ctrl_req_valid(sv[5]), .ctrl_req_ready(sr[5]),
        .ctrl_resp_valid(sx[5]), .ctrl_resp_ready(sy[5]),
        .ctrl_resp_rdata(cdata), .ctrl_resp_err(se[5]),
        .plic_req_valid(sv[6]), .plic_req_ready(sr[6]),
        .plic_resp_valid(sx[6]), .plic_resp_ready(sy[6]),
        .plic_resp_rdata(pdata), .plic_resp_err(se[6])
    );
    serial_mem_bridge #(.POWERUP_CYCLES(PSRAM_POWERUP_CYCLES)) memory (
        .clk(clk), .rst_n(rst_n),
        .ram_req_valid(sv[0]), .ram_req_ready(sr[0]), .ram_req_addr(va),
        .ram_req_write(vw), .ram_req_wdata(vd), .ram_req_wstrb(vs),
        .ram_resp_valid(sx[0]), .ram_resp_ready(sy[0]),
        .ram_resp_rdata(rdata), .ram_resp_err(se[0]),
        .flash_req_valid(sv[1]), .flash_req_ready(sr[1]), .flash_req_addr(va),
        .flash_req_write(vw), .flash_resp_valid(sx[1]), .flash_resp_ready(sy[1]),
        .flash_resp_rdata(fdata), .flash_resp_err(se[1]),
        .ctrl_req_valid(sv[5]), .ctrl_req_ready(sr[5]),
        .ctrl_req_addr(va), .ctrl_req_write(vw),
        .ctrl_req_wdata(vd), .ctrl_req_wstrb(vs),
        .ctrl_resp_valid(sx[5]), .ctrl_resp_ready(sy[5]),
        .ctrl_resp_rdata(cdata), .ctrl_resp_err(se[5]),
        .spi_sck(spi_sck), .spi_cs_n(spi_cs_n),
        .spi_dq_in(spi_dq_in), .spi_dq_out(spi_dq_out), .spi_dq_oe(spi_dq_oe),
        .initialized(memory_initialized)
    );
    uart16550_lite uart (
        .clk(clk), .rst_n(rst_n), .req_valid(sv[2]), .req_ready(sr[2]),
        .req_addr(va), .req_write(vw), .req_wdata(vd), .req_wstrb(vs),
        .resp_valid(sx[2]), .resp_ready(sy[2]),
        .resp_rdata(udata), .resp_err(se[2]),
        .rx_pin(uart_rx), .tx_pin(uart_tx), .irq(uart_irq)
    );
    boot_rom rom (
        .clk(clk), .rst_n(rst_n), .req_valid(sv[3]), .req_ready(sr[3]),
        .req_addr(va), .req_write(vw), .resp_valid(sx[3]),
        .resp_ready(sy[3]), .resp_rdata(odata), .resp_err(se[3])
    );
    clint_timer timer (
        .clk(clk), .rst_n(rst_n), .req_valid(sv[4]), .req_ready(sr[4]),
        .req_addr(va), .req_write(vw), .req_wdata(vd), .req_wstrb(vs),
        .resp_valid(sx[4]), .resp_ready(sy[4]),
        .resp_rdata(tdata), .resp_err(se[4]),
        .irq_timer(timer_irq), .irq_software(software_irq),
        .time_value(time_value)
    );
    plic_lite plic (
        .clk(clk), .rst_n(rst_n), .req_valid(sv[6]), .req_ready(sr[6]),
        .req_addr(va), .req_write(vw), .req_wdata(vd), .req_wstrb(vs),
        .resp_valid(sx[6]), .resp_ready(sy[6]),
        .resp_rdata(pdata), .resp_err(se[6]),
        .source_irq(uart_irq), .supervisor_irq(plic_irq)
    );
    wire unused_retire = &{1'b0, retire_valid, retire_pc};
endmodule
