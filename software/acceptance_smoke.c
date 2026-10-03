/* Small RV32 userspace execution check for the serial Linux acceptance gate. */
#include <stdint.h>
#include <unistd.h>

static volatile uint32_t words[64];

int main(void) {
    uint32_t sum = 0;
    for (uint32_t i = 0; i < 64; ++i)
        words[i] = i * i + 3;
    for (uint32_t i = 0; i < 64; ++i)
        sum += words[i];
    if (sum != 85536)
        return 2;

    static const char message[] = "ASH_PROGRAM_OK\n";
    return write(STDOUT_FILENO, message, sizeof(message) - 1) ==
                   (ssize_t)(sizeof(message) - 1) ? 0 : 3;
}
