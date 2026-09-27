#!/usr/bin/env python3
"""Open a saved LibreLane OpenDB checkpoint in OpenROAD GUI on macOS/XQuartz.

The pinned OpenROAD binary is Linux-only. Relay its X11 connection to the
local XQuartz Unix socket without changing XQuartz's global TCP setting.
"""

from __future__ import annotations

import argparse
import select
import socket
import socketserver
import struct
import subprocess
import tempfile
import threading
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IMAGE = "ghcr.io/librelane/librelane:3.0.14"
XAUTH = "/opt/X11/bin/xauth"
XSOCKET = "/tmp/.X11-unix/X0"


class Relay(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as display:
            display.connect(XSOCKET)
            sockets = (self.request, display)
            while True:
                readable, _, _ = select.select(sockets, [], [])
                for source in readable:
                    data = source.recv(65536)
                    if not data:
                        return
                    (display if source is self.request else self.request).sendall(data)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def current_cookie() -> str:
    entries = subprocess.check_output([XAUTH, "list"], text=True).splitlines()
    for entry in entries:
        parts = entry.split()
        if len(parts) == 3 and parts[0].endswith(":0") and parts[1] == "MIT-MAGIC-COOKIE-1":
            return parts[2]
    raise RuntimeError("XQuartz :0 authorization cookie was not found")


def write_auth(path: Path, display_number: int) -> None:
    # FamilyWild matches the container's hostname without exposing XQuartz TCP.
    fields = (b"", str(display_number).encode(), b"MIT-MAGIC-COOKIE-1",
              bytes.fromhex(current_cookie()))
    with path.open("wb") as output:
        output.write(struct.pack("!H", 65535))
        for field in fields:
            output.write(struct.pack("!H", len(field)))
            output.write(field)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("odb", nargs="?", type=Path,
                        help="OpenROAD .odb checkpoint to inspect")
    parser.add_argument("--run", help="experiment run ID/prefix; use its newest saved ODB")
    args = parser.parse_args()
    if bool(args.odb) == bool(args.run):
        parser.error("provide either an ODB path or --run ID/prefix")
    if args.run:
        runs = [path for path in (ROOT / "build/experiments/runs").iterdir()
                if path.is_dir() and path.name.startswith(args.run)]
        if len(runs) != 1:
            parser.error("--run must match exactly one experiment directory")
        saved = runs[0] / "latest.odb"
        candidates = [saved] if saved.is_file() else list(
            (runs[0] / "pnr-stage/runs/wokwi").rglob("*.odb"))
        if not candidates:
            parser.error("no unpacked ODB checkpoint found for this run")
        odb = max(candidates, key=lambda path: path.stat().st_mtime_ns).resolve()
    else:
        odb = args.odb.expanduser().resolve()
    if not odb.is_file() or odb.suffix != ".odb" or not odb.is_relative_to(ROOT):
        parser.error("ODB must be an existing .odb file inside this repository")
    subprocess.run(["open", "-a", "/Applications/Utilities/XQuartz.app"], check=True)
    for _ in range(50):
        if Path(XSOCKET).exists():
            break
        time.sleep(0.1)
    else:
        raise RuntimeError("XQuartz display socket did not appear")

    display_host = "host.containers.internal"
    server = None
    for display_number in range(10, 100):
        try:
            server = Server(("127.0.0.1", 6000 + display_number), Relay)
            break
        except OSError:
            continue
    if server is None:
        raise RuntimeError("no available local X11 relay port")

    with server, tempfile.TemporaryDirectory(prefix="openroad-x11-", dir=ROOT / "build") as tmp:
        auth = Path(tmp) / "Xauthority"
        auth.touch(mode=0o600)
        write_auth(auth, display_number)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        command = ["podman", "run", "--rm", "--mount",
                   f"type=bind,src={ROOT},dst={ROOT},ro", "--env",
                   f"DISPLAY={display_host}:{display_number}", "--env",
                   f"XAUTHORITY={auth}", "--env", "QT_X11_NO_MITSHM=1",
                   "--entrypoint", "openroad", IMAGE,
                   "-no_init", "-gui", "-db", str(odb)]
        print(f"Opening {odb}", flush=True)
        print("Close the OpenROAD window to stop the viewer.", flush=True)
        try:
            return subprocess.run(command, check=False).returncode
        finally:
            server.shutdown()
            thread.join()


if __name__ == "__main__":
    raise SystemExit(main())
