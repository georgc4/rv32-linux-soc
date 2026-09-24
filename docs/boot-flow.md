# Boot path and remaining stages

The integrated diagnostic path is implemented and simulated: ROM at physical address zero waits for the SPI bridge, reads 88 words from NOR flash, writes them to PSRAM at `0x8000_0000`, jumps there, and the test program sends `OK\n` through the serial UART. The boot ROM simply stalls on its first flash read until PSRAM initialization finishes; it has no image validity check or recovery mechanism.

1. Reset holds memory CS# inactive. The CPU fetches immutable ROM at a defined physical reset vector. ROM establishes a stack (tiny on-chip storage or a carefully initialized PSRAM region), clock/timer state, UART recovery, and a safe serial-memory mode.
2. ROM verifies a flash image manifest and copies a first-stage firmware into PSRAM. A recovery loader can receive and program an image through UART. This avoids requiring flash execute-in-place.
3. M-mode firmware initializes memory, protects its resident region if required, supplies timer/interrupt and SBI services to S-mode, and loads a Linux image plus DTB and minimal initramfs from flash. The minimum SBI and device-tree contract must be established against the chosen kernel; OpenSBI is a reference, not adopted product firmware.
4. Enter S-mode with `satp=0`, `a0=hartid`, `a1=physical DTB pointer`, interrupts and delegation set as required, and a 4 MiB aligned RV32 kernel placement. Linux enables Sv32 and starts userspace.
5. `init` opens the UART console, starts the selected shell, and runs the classifier.

The reset/PSRAM command sequence and basic SPI transactions have behavioral simulation coverage, but there is no board-level timing or electrical verification. ROM size, image manifest, firmware footprint, flash update atomicity, and Linux load address remain open. A ROM diagnostic test cannot establish kernel boot. Record image hashes and raw UART logs at each stage.
