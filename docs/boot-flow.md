# Boot flow

The current detailed account is [from reset to an interactive shell](boot/boot-chain.md). It covers the 27-word ROM, RVSB header, loader copy, LNX1 manifest, DTB/Image placement, resident M-mode SBI handler, Linux S-mode entry, `/init`, and the UART-driven BusyBox ash program gate. [Linux image and programs](boot/linux-image-and-programs.md) documents the build inputs and device tree.

The previous version of this note stopped at the early `/init` milestone; it is preserved in Git history. The current full serial simulation reaches the ash prompt, sends a command into the SoC UART RX pin, and observes a user program's output from UART TX. Hardware board validation remains open.
