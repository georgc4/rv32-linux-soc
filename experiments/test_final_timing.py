"""Regression coverage for final-corner selection and fail-closed qualification."""
import json
import tempfile
import unittest
from pathlib import Path

from experiments.runner import collect_pnr_metrics
from experiments.physical_profiles import flow_overrides


class FinalTimingTest(unittest.TestCase):
    def fixture(self, base, slow_slack=-9.4466):
        root = Path(base) / "runs/wokwi"
        (root / "final").mkdir(parents=True)
        (root / "43-openroad-stamidpnr-3").mkdir()
        (root / "resolved.json").write_text(json.dumps({"STA_CORNERS": ["tt", "ss"]}))
        (root / "43-openroad-stamidpnr-3/or_metrics_out.json").write_text(json.dumps({
            "timing__setup__wns__corner:tt": 0,
            "timing__setup_r2r__ws__corner:tt": 26.564,
        }))
        m = {}
        for c, slack in (("ss", slow_slack), ("tt", 21.2)):
            for k, v in {"timing__setup__ws": slack, "timing__setup__wns": min(0, slack),
                         "timing__hold__ws": .0265, "timing__setup__tns": min(0, slack),
                         "timing__hold__tns": 0, "timing__setup_vio__count": int(slack < 0),
                         "timing__hold_vio__count": 0, "design__max_slew_violation__count": 0,
                         "design__max_cap_violation__count": 0}.items():
                m[k + "__corner:" + c] = v
        (root / "final/metrics.json").write_text(json.dumps(m))
        return root, m

    def test_slow_corner_cannot_be_hidden_by_typical_or_midflow(self):
        with tempfile.TemporaryDirectory() as d:
            self.fixture(d)
            r = collect_pnr_metrics(Path(d))
            self.assertEqual(r["setup_wns_ns"], -9.4466)
            self.assertEqual(r["timing"]["status"], "failed")
            self.assertEqual(r["timing_stage"], "final/metrics.json")

    def test_missing_corner_fails_closed(self):
        with tempfile.TemporaryDirectory() as d:
            root, m = self.fixture(d, 1)
            del m["timing__hold__ws__corner:ss"]
            (root / "final/metrics.json").write_text(json.dumps(m))
            self.assertEqual(collect_pnr_metrics(Path(d))["timing"]["status"], "missing")

    def test_electrical_violations_block_timing_qualification(self):
        with tempfile.TemporaryDirectory() as d:
            root, m = self.fixture(d, 1)
            m["design__max_slew_violation__count__corner:ss"] = 3
            (root / "final/metrics.json").write_text(json.dumps(m))
            r = collect_pnr_metrics(Path(d))["timing"]
            self.assertEqual(r["setup_hold_status"], "pass")
            self.assertEqual(r["status"], "failed")

    def test_clean_and_deferred_failure_reports(self):
        with tempfile.TemporaryDirectory() as d:
            root, m = self.fixture(d, 1)
            self.assertEqual(collect_pnr_metrics(Path(d))["timing"]["status"], "pass")
            (root / "final/metrics.json").unlink()
            sta = root / "55-openroad-stapostpnr"
            sta.mkdir()
            (sta / "state_out.json").write_text(json.dumps({"metrics": m}))
            self.assertEqual(collect_pnr_metrics(Path(d))["timing"]["status"], "pass")
            (sta / "state_out.json").unlink()
            self.assertEqual(collect_pnr_metrics(Path(d))["timing"]["status"], "missing")

    def test_cluster_requires_registered_flow_and_corners(self):
        c = flow_overrides({"cluster_profile": "timer_csr", "corner_profile": "multicorner"})
        self.assertEqual(c["meta"]["substituting_steps"]["OpenROAD.GlobalPlacement"],
                         "Locality.GlobalPlacement")
        self.assertEqual(c["SETUP_VIOLATION_CORNERS"], ["*"])
        with self.assertRaises(ValueError):
            flow_overrides({"cluster_profile": "typo"})


if __name__ == "__main__":
    unittest.main()
