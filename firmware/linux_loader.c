#include <stdint.h>

#define FLASH_BASE 0x20000000u
#define MANIFEST_OFF 0x00040000u
#define DTB_FLASH_OFF 0x00040020u
#define KERNEL_FLASH_OFF 0x00041000u
#define DTB_RAM 0x803f0000u
#define KERNEL_RAM 0x80400000u
#define RAM_END 0x82000000u
#define FLASH_END 0x01000000u
#define UART_TX (*(volatile uint8_t *)0x10000000u)
#define MTIMECMP_LO (*(volatile uint32_t *)0x02004000u)
#define MTIMECMP_HI (*(volatile uint32_t *)0x02004004u)
#define LNX_MAGIC 0x31584e4cu /* LNX1 */
#define SBI_BASE 0x10u
#define SBI_TIME 0x54494d45u

struct trap_frame { uint32_t x[32]; };
extern void m_trap_entry(void);

static inline uint32_t read_mcause(void) { uint32_t v; __asm__ volatile ("csrr %0, mcause" : "=r"(v)); return v; }
static inline uint32_t read_mepc(void) { uint32_t v; __asm__ volatile ("csrr %0, mepc" : "=r"(v)); return v; }
static inline uint32_t read_mstatus(void) { uint32_t v; __asm__ volatile ("csrr %0, mstatus" : "=r"(v)); return v; }
static inline void write_mepc(uint32_t v) { __asm__ volatile ("csrw mepc, %0" :: "r"(v)); }
static inline void write_mstatus(uint32_t v) { __asm__ volatile ("csrw mstatus, %0" :: "r"(v)); }
static inline void set_stip(void) { uint32_t v = 1u << 5; __asm__ volatile ("csrs mip, %0" :: "r"(v)); }
static inline void clear_stip(void) { uint32_t v = 1u << 5; __asm__ volatile ("csrc mip, %0" :: "r"(v)); }

static void set_timer(uint32_t lo, uint32_t hi) {
    /* Write high first to avoid an intermediate compare in the past. */
    MTIMECMP_HI = UINT32_MAX;
    MTIMECMP_LO = lo;
    MTIMECMP_HI = hi;
}

__attribute__((noreturn)) static void fail(char code) {
    UART_TX = (uint8_t)code;
    for (;;) __asm__ volatile ("wfi");
}

static uint32_t copy_words(uint32_t flash_off, uint32_t ram_addr, uint32_t bytes) {
    volatile const uint32_t *src = (volatile const uint32_t *)(FLASH_BASE + flash_off);
    volatile uint32_t *dst = (volatile uint32_t *)ram_addr;
    uint32_t sum = 0;
    for (uint32_t i = 0; i < (bytes + 3u) / 4u; ++i) {
        uint32_t word = src[i];
        dst[i] = word;
        sum += word;
    }
    return sum;
}

void m_trap(struct trap_frame *f) {
    uint32_t cause = read_mcause();
    if (cause == 0x80000007u) {
        set_timer(UINT32_MAX, UINT32_MAX);
        set_stip();
        return;
    }
    if (cause != 9u) fail('T');

    uint32_t eid = f->x[17], fid = f->x[16];
    uint32_t arg0 = f->x[10], arg1 = f->x[11];
    uint32_t error = (uint32_t)-2, value = 0;
    if (eid == SBI_BASE) {
        error = 0;
        switch (fid) {
        case 0: value = 2; break; /* SBI v0.2 */
        case 1: value = 0x80000000u; break; /* local implementation ID */
        case 2: value = 1; break;
        case 3: value = (arg0 == SBI_BASE || arg0 == SBI_TIME) ? 1u : 0u; break;
        case 4: case 5: case 6: value = 0; break;
        default: error = (uint32_t)-2; break;
        }
    } else if (eid == SBI_TIME && fid == 0) {
        clear_stip();
        set_timer(arg0, arg1);
        error = 0;
    }
    f->x[10] = error;
    f->x[11] = value;
    write_mepc(read_mepc() + 4u);
}

__attribute__((noreturn)) void firmware_main(void) {
    volatile const uint32_t *manifest = (volatile const uint32_t *)(FLASH_BASE + MANIFEST_OFF);
    UART_TX = 'L';
    if (manifest[0] != LNX_MAGIC) fail('H');
    uint32_t kernel_bytes = manifest[1];
    uint32_t kernel_sum = manifest[2];
    uint32_t dtb_bytes = manifest[3];
    uint32_t dtb_sum = manifest[4];
    uint32_t runtime_bytes = manifest[5];
    if (!kernel_bytes || (kernel_bytes & 3u) ||
        kernel_bytes > FLASH_END - KERNEL_FLASH_OFF ||
        runtime_bytes < kernel_bytes || runtime_bytes > RAM_END - KERNEL_RAM ||
        !dtb_bytes || dtb_bytes > 0x0fe0u) fail('H');
    if (copy_words(DTB_FLASH_OFF, DTB_RAM, dtb_bytes) != dtb_sum) fail('D');
    if (copy_words(KERNEL_FLASH_OFF, KERNEL_RAM, kernel_bytes) != kernel_sum) fail('K');
    volatile uint32_t *tail = (volatile uint32_t *)(KERNEL_RAM + kernel_bytes);
    for (uint32_t i = kernel_bytes; i < runtime_bytes; i += 4u)
        *tail++ = 0;
    UART_TX = 'B';

    set_timer(UINT32_MAX, UINT32_MAX);
    clear_stip();
    __asm__ volatile ("csrw mtvec, %0" :: "r"((uint32_t)m_trap_entry));
    __asm__ volatile ("csrw mscratch, %0" :: "r"(0x803efff0u));
    /* S-mode ECALL (cause 9) must remain a machine trap for SBI. */
    __asm__ volatile ("csrw medeleg, %0" :: "r"(0x0000b1ffu));
    __asm__ volatile ("csrw mideleg, %0" :: "r"(0x00000222u));
    __asm__ volatile ("csrw mcounteren, %0" :: "r"(2u));
    __asm__ volatile ("csrw mie, %0" :: "r"(0x80u));
    __asm__ volatile ("csrw satp, zero");
    write_mepc(KERNEL_RAM);
    write_mstatus((read_mstatus() & ~(3u << 11)) | (1u << 11));
    register uint32_t hartid __asm__("a0") = 0;
    register uint32_t fdt __asm__("a1") = DTB_RAM;
    __asm__ volatile ("mret" :: "r"(hartid), "r"(fdt) : "memory");
    __builtin_unreachable();
}
