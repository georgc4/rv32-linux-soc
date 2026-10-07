/* Directed dependency and write-first alias checks; no register preload. */
.option norvc
.section .text
.global _start
_start:
    lui t0, 0x80001
    addi x0, x0, 99
    addi t1, x0, 5
    addi t2, x0, 7
    add t1, t1, t2
    sw t1, 0(t0)           /* rd == rs1: 12 */
    add t2, t1, t2
    sw t2, 4(t0)           /* rd == rs2: 19 */
    add t2, t2, t2
    sw t2, 8(t0)           /* all equal: 38 */
    add t3, x0, x0
    sw t3, 12(t0)          /* x0 is hard zero */
    addi t1, x0, 10
    sw t1, 64(t0)
    addi t4, t0, 64
    addi t2, x0, 3
    amoadd.w t2, t2, (t4)  /* rd == rs2: result 10, memory 13 */
    sw t2, 16(t0)
    lw t3, 64(t0)
    sw t3, 20(t0)
    addi t2, x0, 4
    amoadd.w t4, t2, (t4)  /* rd == rs1: result 13, memory 17 */
    sw t4, 24(t0)
    lw t3, 64(t0)
    sw t3, 28(t0)
    addi t4, t0, 64
    amoswap.w t4, t4, (t4) /* all equal: result 17, memory old address */
    sw t4, 32(t0)
    lw t3, 64(t0)
    sw t3, 36(t0)
    addi t4, t0, 64
    addi t2, x0, 123
    amoswap.w x0, t2, (t4) /* discard destination but perform store */
    sw x0, 40(t0)
    lw t3, 64(t0)
    sw t3, 44(t0)
    lr.w t2, (t4)
    sc.w t2, t2, (t4)      /* rd == rs2 on successful SC */
    sw t2, 48(t0)
    lw t3, 64(t0)
    sw t3, 52(t0)
    sc.w t2, t2, (t4)      /* failed SC returns 1 */
    sw t2, 56(t0)
    ebreak
