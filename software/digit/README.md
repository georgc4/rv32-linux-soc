# Software-only digit baseline

`digit_demo.c` reads exactly 64 decimal grayscale pixels (0–255, row-major) from standard input and prints the closest digit and L1 score. The model is ten fixed 8×8 **binary prototypes** with integer arithmetic; it has no training data and no measured accuracy on handwritten digits. This demonstrates a complete input/output path and establishes a reference before considering a custom instruction.

On a host: `make test-digit`. The three checked-in fixtures test clean 0 and 8 plus a dim/noisy 1. Next: select a small licensed 8×8 digit dataset, train/evaluate a quantized model, freeze a held-out test set and measure accuracy, flash/image size and CPU cycles. A RISC-V Linux binary requires a chosen kernel ABI and cross compiler; this host executable is not evidence of operation on the SoC.
