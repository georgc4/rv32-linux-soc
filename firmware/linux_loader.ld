OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
    . = 0x80000000;
    .text : { *(.text.entry) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.sdata*) *(.data*) }
    PROVIDE(__global_pointer$ = . + 0x800);
    . = ALIGN(4);
    __bss_start = .;
    .bss (NOLOAD) : { *(.sbss*) *(.bss*) *(COMMON) }
    . = ALIGN(4);
    __bss_end = .;
    _end = .;
    /DISCARD/ : { *(.eh_frame*) *(.comment*) }
}
ASSERT(_end < 0x80040000, "firmware exceeds 256 KiB ROM stage budget")
