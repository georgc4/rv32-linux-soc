    .option norvc
    .section .text
    .global _start
_start:
    lui   t0, 0x80000
    addi  t1, t0, 64
    csrw  mtvec, t1
    ecall
    addi  t2, zero, 1
    sw    t2, 128(t0)
    addi  t1, zero, 0x80
    csrw  mie, t1
    addi  t1, zero, 8
    csrw  mstatus, t1
loop:
    jal   zero, loop
    .org 0x40
handler:
    csrr  t3, mcause
    blt   t3, zero, timer_handler
    sw    t3, 132(t0)
    csrr  t4, mepc
    addi  t4, t4, 4
    csrw  mepc, t4
    mret
timer_handler:
    sw    t3, 136(t0)
    csrw  mie, zero
    mret
