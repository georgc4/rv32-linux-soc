"""Staged-local LibreLane plugin; never modifies the installed flow."""

from pathlib import Path

from librelane.common import get_script_dir
from librelane.config import Variable
from librelane.steps import Step
from librelane.steps.openroad import GlobalPlacement


@Step.factory.register()
class LocalityPlacement(GlobalPlacement):
    id = "Locality.GlobalPlacement"
    config_vars = GlobalPlacement.config_vars + [
        Variable("LOCALITY_PROFILE", str, "Connectivity cluster selection", default="none")
    ]

    def get_script_path(self):
        original = Path(get_script_dir()) / "openroad/gpl.tcl"
        text = original.read_text()
        anchor = "log_cmd global_placement {*}$arg_list"
        if text.count(anchor) != 1:
            raise RuntimeError("Pinned GPL hook changed; refusing unverified injection")
        hook = Path(__file__).with_name("placement_clusters.tcl")
        target = Path(self.step_dir) / "gpl-locality.tcl"
        target.write_text(text.replace(anchor, f"source {{{hook}}}\n{anchor}"))
        return str(target)
