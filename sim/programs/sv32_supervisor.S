    .option norvc
    .section .text
    .global _start
_start:
    lui   t0, 0x80000       /* physical RAM base */
    lui   t1, 0x80001       /* root at 0x80001000 */
    lui   t2, 0x80002       /* next-level table at 0x80002000 */
    lui   t3, 0x20001       /* (0x80002 << 10) | V */
    addi  t3, t3, -2047
    sw    t3, 1024(t1)     /* VPN[1] = 256 */
    lui   t3, 0x20000       /* physical leaf PPN = 0x80000 */
    addi  t3, t3, 0xcf     /* V R W X A D */
    sw    t3, 0(t2)        /* VPN[0] = 0 */
    lui   t3, 0x80080      /* satp mode Sv32, root PPN 0x80001 */
    addi  t3, t3, 1
    csrw  satp, t3
    lui   t4, 0x40000
    addi  t4, t4, 0xa0
    csrw  stvec, t4
    addi  t4, zero, 0x200
    csrw  mideleg, t4
    csrw  mie, t4
    lui   t3, 0x1
    addi  t3, t3, -2046  /* MPP=S, SIE=1 */
    csrw  mstatus, t3
    lui   t3, 0x40000
    addi  t3, t3, 0x80
    csrw  mepc, t3
    mret
    .org 0x80
supervisor:
    addi  t3, zero, 42
    lui   t4, 0x40000
    sw    t3, 256(t4)      /* translated store at physical 0x80000100 */
loop:
    jal   zero, loop
    .org 0xa0
supervisor_irq:
    csrr  t3, scause
    lui   t4, 0x40000
    sw    t3, 260(t4)
    csrw  sie, zero
    sret
