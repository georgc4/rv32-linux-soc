from pathlib import Path
import subprocess

root = Path(__file__).parent
for name, expected in (("zero", 0), ("one_dim", 1), ("eight", 8)):
    pixels = (root / "fixtures" / f"{name}.txt").read_text()
    assert len(pixels.split()) == 64, name
    result = subprocess.run(
        [str(root.parent.parent / "build" / "digit_demo")],
        input=pixels,
        text=True,
        capture_output=True,
        check=True,
    )
    assert result.stdout.startswith(f"digit={expected} "), (name, result.stdout)
    print(f"PASS {name}: {result.stdout.strip()}")
