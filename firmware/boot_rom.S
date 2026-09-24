/* Immutable first stage. Header at NOR offset zero:
 *   magic 0x52565342 ("RVSB"), word count [1,65535], 32-bit sum, reserved.
 * Payload begins at byte offset 16 and is copied to physical 0x80000000.
 * The entry is the payload's first word. The checksum catches transfer errors,
 * but is not a cryptographic authenticity check. On failure send 'E' and loop.
 */
    .option norvc
    .section .text
    .global _start
_start:
    lui   t0, 0x20000
    lw    t1, 0(t0)
    li    t2, 0x52565342
    bne   t1, t2, error
    lw    t1, 4(t0)
    beq   t1, zero, error
    lui   t2, 0x10
    bgeu  t1, t2, error
    lw    t5, 8(t0)
    addi  t0, t0, 16
    lui   t3, 0x80000
    addi  t4, zero, 0
copy:
    lw    t2, 0(t0)
    add   t4, t4, t2
    sw    t2, 0(t3)
    addi  t0, t0, 4
    addi  t3, t3, 4
    addi  t1, t1, -1
    bne   t1, zero, copy
    bne   t4, t5, error
    lui   t3, 0x80000
    jalr  zero, 0(t3)
error:
    lui   a0, 0x10000
    addi  a1, zero, 69
    sb    a1, 0(a0)
halt:
    jal   zero, halt
