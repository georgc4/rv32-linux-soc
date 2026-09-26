"""Fail-closed checks for the final-GDS experiment gate."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from experiments import runner


class PhysicalGateTest(unittest.TestCase):
    def make_run(self, base: Path) -> tuple[Path, Path, str]:
        run_dir = base / "run"
        stage = run_dir / "pnr-stage"
        root = stage / "runs/wokwi"
        revision = "a" * 40
        deck = base / ".volare/ciel/sky130/versions" / revision / \
            "sky130A/libs.tech/klayout/drc/sky130A_mr.drc"
        deck.parent.mkdir(parents=True)
        deck.write_text("rule deck")
        files = {
            "final/gds/tt_um_rv32_linux_soc.gds": "GDS",
            "66-netgen-lvs/reports/lvs.netgen.rpt": "Final result: Circuits match uniquely.\n",
            "66-netgen-lvs/reports/lvs.netgen.json": json.dumps(
                [{"badnets": [], "badelements": []}]),
            "62-magic-drc/reports/drc.magic.rpt": "[INFO] COUNT: 0\n",
            "46-openroad-checkantennas-1/reports/antenna_summary.rpt":
                "┃ P / R ┃ Net ┃\n┡━━━━━━━╇━━━━━┩\n└───────┴─────┘\n",
        }
        for name, contents in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
        return run_dir, stage, revision

    @staticmethod
    def fake_klayout(command, cwd, log_path, timeout):
        report = next(arg.removeprefix("report=") for arg in command
                      if arg.startswith("report="))
        Path(report).write_text("<report-database><items></items></report-database>")
        return "pass", 0

    def test_complete_clean_reports_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            run_dir, stage, revision = self.make_run(base)
            with patch("experiments.runner.Path.home", return_value=base), \
                    patch("experiments.runner.shutil.which", return_value="klayout"), \
                    patch("experiments.runner.run_logged", side_effect=self.fake_klayout):
                checks = runner.check_physical_artifacts(run_dir, stage, revision, 60)
            self.assertTrue(all(value["status"] == "pass" for value in checks.values()))
            self.assertEqual(checks["klayout_drc"]["violations"], 0)

    def test_antenna_and_lvs_mismatch_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            run_dir, stage, revision = self.make_run(base)
            root = stage / "runs/wokwi"
            (root / "46-openroad-checkantennas-1/reports/antenna_summary.rpt").write_text(
                "┃ P / R ┃ Net ┃\n│ 1.53 │ bad │\n")
            (root / "66-netgen-lvs/reports/lvs.netgen.json").write_text(
                json.dumps([{"badnets": ["short"], "badelements": []}]))
            with patch("experiments.runner.Path.home", return_value=base), \
                    patch("experiments.runner.shutil.which", return_value="klayout"), \
                    patch("experiments.runner.run_logged", side_effect=self.fake_klayout):
                checks = runner.check_physical_artifacts(run_dir, stage, revision, 60)
            self.assertEqual(checks["antenna"]["status"], "failed")
            self.assertEqual(checks["antenna"]["violations"], 1)
            self.assertEqual(checks["lvs"]["status"], "failed")

    def test_missing_report_cannot_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            run_dir, stage, revision = self.make_run(base)
            (stage / "runs/wokwi/62-magic-drc/reports/drc.magic.rpt").unlink()
            with patch("experiments.runner.Path.home", return_value=base), \
                    patch("experiments.runner.shutil.which", return_value="klayout"), \
                    patch("experiments.runner.run_logged", side_effect=self.fake_klayout):
                checks = runner.check_physical_artifacts(run_dir, stage, revision, 60)
            self.assertEqual(checks["magic_drc"]["status"], "failed")


if __name__ == "__main__":
    unittest.main()
