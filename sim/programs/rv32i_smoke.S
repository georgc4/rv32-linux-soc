/* Linked at the diagnostic RAM base 0x80000000; no runtime or C library. */
    .option norvc
    .section .text
    .global _start
_start:
    lui   t0, 0x80001       /* scratch at 0x80001000 */
    addi  t1, zero, 0x123
    sw    t1, 0(t0)
    lw    t2, 0(t0)
    bne   t1, t2, fail

    addi  t3, zero, -1
    sb    t3, 4(t0)
    lbu   t4, 4(t0)
    addi  t5, zero, 255
    bne   t4, t5, fail
    lb    t4, 4(t0)
    bne   t4, t3, fail
    sh    t1, 6(t0)
    lhu   t4, 6(t0)
    bne   t4, t1, fail

    addi  t2, zero, -8
    srai  t2, t2, 2
    addi  t4, zero, -2
    bne   t2, t4, fail
    slti  t2, t2, 0
    addi  t4, zero, 1
    bne   t2, t4, fail
    addi  zero, zero, 7
    bne   zero, zero, fail

    addi  t1, zero, -1
    addi  t2, zero, 2
    mul   t3, t1, t2
    addi  t4, zero, -2
    bne   t3, t4, fail
    mulh  t3, t1, t2
    bne   t3, t1, fail
    mulhsu t3, t1, t2
    bne   t3, t1, fail
    mulhu t3, t1, t2
    addi  t4, zero, 1
    bne   t3, t4, fail
    addi  t1, zero, -7
    div   t3, t1, t2
    addi  t4, zero, -3
    bne   t3, t4, fail
    rem   t3, t1, t2
    addi  t4, zero, -1
    bne   t3, t4, fail
    divu  t3, t1, zero
    bne   t3, t4, fail
    remu  t3, t1, zero
    bne   t3, t1, fail
    lui   t1, 0x80000
    div   t3, t1, t4
    bne   t3, t1, fail
    rem   t3, t1, t4
    bne   t3, zero, fail

    auipc t2, 0
    sw    t2, 8(t0)
    jal   ra, uart_message
    lui   t1, 0x5a5aa
    addi  t1, t1, 0x5a5
    sw    t1, 12(t0)
    ebreak

fail:
    sw    zero, 12(t0)
    ebreak

uart_message:
    lui   a0, 0x10000
    addi  a1, zero, 79
    sb    a1, 0(a0)
    addi  a1, zero, 75
    sb    a1, 0(a0)
    addi  a1, zero, 10
    sb    a1, 0(a0)
    jalr  zero, 0(ra)
