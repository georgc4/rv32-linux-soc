/* Minimal diagnostic first stage: copy 88 words from NOR to PSRAM and jump.
 * This is not yet Linux firmware or a recovery/update implementation.
 */
    .option norvc
    .section .text
    .global _start
_start:
    lui   t0, 0x20000
    lui   t1, 0x80000
    addi  t2, zero, 88
copy:
    lw    t3, 0(t0)
    sw    t3, 0(t1)
    addi  t0, t0, 4
    addi  t1, t1, 4
    addi  t2, t2, -1
    bne   t2, zero, copy
    lui   t1, 0x80000
    jalr  zero, 0(t1)
