"""Electrical ECO driven by a matching routed ODB and extracted parasitics."""
import json
from pathlib import Path

from librelane.common import get_script_dir
from librelane.config import Variable
from librelane.steps import Step
from librelane.steps.openroad import RepairDesignPostGRT


@Step.factory.register()
class ExtractedRepair(RepairDesignPostGRT):
    id = 'Electrical.ExtractedRepair'
    config_vars = RepairDesignPostGRT.config_vars + [
        Variable('ELECTRICAL_SPEF_MAP', str, 'Matching extracted parasitics by implementation corner')]

    def get_script_path(self):
        text = (Path(get_script_dir()) / 'openroad/repair_design_postgrt.tcl').read_text()
        for anchor in ['read_current_odb', 'estimate_parasitics -global_routing',
                       'log_cmd repair_design {*}$arg_list']:
            if text.count(anchor) != 1:
                raise RuntimeError('Pinned repair script changed: ' + anchor)
        mapping = json.loads(Path(self.config['ELECTRICAL_SPEF_MAP']).read_text())
        if set(mapping) != set(self.config['PNR_CORNERS']):
            raise ValueError('Every implementation corner needs matching extracted parasitics')
        commands = []
        for corner, path in mapping.items():
            if not Path(path).is_file() or any(c in path + corner for c in '{}\n'):
                raise ValueError('Invalid SPEF path or corner')
            commands.append(f'read_spef -corner {{{corner}}} {{{path}}}')
        commands.append('report_check_types -max_slew -max_cap -violators')
        text = text.replace('read_current_odb', 'read_current_odb\nremove_fillers')
        # Initial routing supplies topology for ECO buffering; extracted RC from
        # the unchanged input netlist supplies the measured electrical loads.
        text = text.replace('estimate_parasitics -global_routing', '\n'.join(commands))
        text = text.replace('log_cmd repair_design {*}$arg_list',
                            'log_cmd repair_design {*}$arg_list\n'
                            'log_cmd repair_clock_nets -max_wire_length 200')
        target = Path(self.step_dir) / 'repair-extracted.tcl'
        target.write_text(text)
        return str(target)
