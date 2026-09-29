"""Opt-in router-feedback placement for isolated experiments."""
from pathlib import Path

from librelane.common import get_script_dir
from librelane.steps import Step
from librelane.steps.openroad import GlobalPlacement


@Step.factory.register()
class RouterFeedbackPlacement(GlobalPlacement):
    id = "RouterFeedback.GlobalPlacement"

    def get_script_path(self):
        if not self.config["PL_ROUTABILITY_DRIVEN"]:
            raise ValueError("Router feedback requires routability-driven placement")
        original = Path(get_script_dir()) / "openroad/gpl.tcl"
        text = original.read_text()
        anchor = "log_cmd global_placement {*}$arg_list"
        if text.count(anchor) != 1:
            raise RuntimeError("Pinned GPL hook changed; refusing injection")
        target = Path(self.step_dir) / "gpl-router-feedback.tcl"
        target.write_text(text.replace(
            anchor, "lappend arg_list -routability_use_grt\n" + anchor))
        return str(target)
