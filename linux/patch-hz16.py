#!/usr/bin/env python3
"""Add a 16 Hz tick and safe jiffies shift to pinned Linux 6.12, idempotently."""
from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-hz16.py path/to/kernel/Kconfig.hz")
path = Path(sys.argv[1])
text = path.read_text()
if "config HZ_16\n" in text:
    pass
elif "config HZ_10\n" in text:
    text = text.replace("config HZ_10\n", "config HZ_16\n")
    text = text.replace("10 HZ (slow serial-memory prototype)",
                        "16 HZ (slow serial-memory prototype)")
    text = text.replace("default 10 if HZ_10", "default 16 if HZ_16")
else:
    choice = "\tconfig HZ_100\n"
    default = "\tdefault 100 if HZ_100\n"
    if text.count(choice) != 1 or text.count(default) != 1:
        raise SystemExit("unexpected Linux Kconfig.hz layout")
    text = text.replace(choice,
        "\tconfig HZ_16\n"
        "\t\tbool \"16 HZ (slow serial-memory prototype)\"\n"
        "\thelp\n"
        "\t  A lower periodic tick for processors whose external-memory\n"
        "\t  latency exceeds a standard 100 Hz timer interval.\n\n"
        + choice)
    text = text.replace(default, "\tdefault 16 if HZ_16\n" + default)
if text != path.read_text():
    path.write_text(text)

tick_path = path.parent / "time/tick-internal.h"
tick = tick_path.read_text()
if "#if HZ < 17\n#define JIFFIES_SHIFT\t5\n" not in tick:
    original = "#if HZ < 34\n#define JIFFIES_SHIFT\t6\n"
    replacement = ("#if HZ < 17\n#define JIFFIES_SHIFT\t5\n"
                   "#elif HZ < 34\n#define JIFFIES_SHIFT\t6\n")
    if tick.count(original) != 1:
        raise SystemExit("unexpected Linux tick-internal.h layout")
    tick_path.write_text(tick.replace(original, replacement))
