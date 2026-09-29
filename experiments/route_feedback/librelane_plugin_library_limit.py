"""Apply a measured, targeted electrical ECO without broad clock-tree repair."""
from pathlib import Path
from librelane.common import get_script_dir
from librelane.config import Variable
from librelane.steps import Step
from librelane.steps.openroad import RepairDesignPostGRT


@Step.factory.register()
class LibraryLimitRepair(RepairDesignPostGRT):
    id = 'Electrical.LibraryLimitRepair'
    config_vars = RepairDesignPostGRT.config_vars + [
        Variable('ELECTRICAL_TARGETED_TCL', str, 'Reviewed targeted ECO Tcl')]

    def get_script_path(self):
        text = (Path(get_script_dir()) / 'openroad/repair_design_postgrt.tcl').read_text()
        for anchor in ['read_current_odb', 'log_cmd repair_design {*}$arg_list']:
            if text.count(anchor) != 1:
                raise RuntimeError('Pinned repair script changed')
        text = text.replace('read_current_odb', '''read_current_odb
remove_fillers
foreach net [$::block getNets] {
    if {[$net getSigType] in {POWER GROUND}} {continue}
    set wire [$net getWire]
    if {$wire != "NULL"} {odb::dbWire_destroy $wire}
}
''')
        eco = str(self.config['ELECTRICAL_TARGETED_TCL'])
        if not Path(eco).is_file() or any(c in eco for c in '{}\n'):
            raise ValueError('Invalid ECO path')
        text = text.replace('log_cmd repair_design {*}$arg_list', f'source {{{eco}}}')
        target = Path(self.step_dir) / 'repair-library-limit.tcl'
        target.write_text(text)
        return str(target)
