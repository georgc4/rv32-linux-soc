    .option norvc
    .section .text
    .globl _image_start
    .globl _start
_image_start:
_start:
    j _kernel_start
    .word 0
    .dword 0x400000
    .dword _image_end - _image_start
    .dword 0
    .word 2
    .word 0
    .dword 0
    .ascii "RISCV\0\0\0"
    .word 0x05435352
    .word 0

_kernel_start:
    li sp, 0x80700000
    bnez a0, fail
    li t0, 0x803f0000
    bne a1, t0, fail
    li a7, 0x10
    li a6, 0
    ecall
    bnez a0, fail
    li t0, 2
    bne a1, t0, fail
    li a7, 0x10
    li a6, 3
    li a0, 0x54494d45
    ecall
    bnez a0, fail
    li t0, 1
    bne a1, t0, fail
    li t0, 0x10000000
    li t1, 'S'
    sb t1, 0(t0)
    la t0, s_timer
    csrw stvec, t0
    li t0, 0x20
    csrs sie, t0
    li t0, 0x2
    csrs sstatus, t0
    csrr a0, time
    li t0, 10000
    add a0, a0, t0
    li a1, 0
    li a6, 0
    li a7, 0x54494d45
    ecall
    bnez a0, fail
wait:
    wfi
    j wait
s_timer:
    li t0, 0x10000000
    li t1, 'T'
    sb t1, 0(t0)
    li a0, -1
    li a1, -1
    li a6, 0
    li a7, 0x54494d45
    ecall
    bnez a0, fail
    li t0, 0x0c000000
    li t1, 1
    sw t1, 4(t0)
    li t0, 0x0c002000
    li t1, 2
    sw t1, 0(t0)
    li t0, 0x10000004
    sb t1, 0(t0)
    la t0, s_external
    csrw stvec, t0
    li t0, 0x200
    csrs sie, t0
    li t0, 2
    csrs sstatus, t0
1:  wfi
    j 1b
s_external:
    li t0, 0x0c200004
    lw t1, 0(t0)
    li t2, 1
    bne t1, t2, fail
    li t2, 0x10000004
    sb zero, 0(t2)
    sw t1, 0(t0)
    li t0, 0x10000000
    li t1, 'P'
    sb t1, 0(t0)
3:  j 3b
fail:
    li t0, 0x10000000
    li t1, 'F'
    sb t1, 0(t0)
2:  j 2b
_image_end:
