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
loop:
    jal   zero, loop
    .org 0x40
handler:
    csrr  t3, mcause
    sw    t3, 132(t0)
    csrr  t4, mepc
    addi  t4, t4, 4
    csrw  mepc, t4
    mret
