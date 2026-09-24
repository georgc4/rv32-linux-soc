"""Convert a little-endian RV32 flat binary to one 32-bit word per memh line."""
import struct
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_bytes()
if len(source) % 4:
    raise SystemExit("program length is not word aligned")
words = struct.unpack(f"<{len(source) // 4}I", source)
Path(sys.argv[2]).write_text("".join(f"{word:08x}\n" for word in words))
