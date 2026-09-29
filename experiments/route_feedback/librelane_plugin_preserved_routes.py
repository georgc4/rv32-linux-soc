"""Route only the ECO nets; retained detailed wires must be encoded FIXED."""
import json
from pathlib import Path
from librelane.config import Variable
from librelane.steps import Step
from librelane.steps.openroad import RepairDesignPostGRT


@Step.factory.register()
class PreservedRouteRepair(RepairDesignPostGRT):
    id = 'Electrical.PreservedRouteRepair'
    config_vars = RepairDesignPostGRT.config_vars + [
        Variable('ELECTRICAL_PREPARATION_JSON', str, 'Verified route preservation manifest')]

    def get_script_path(self):
        manifest = json.loads(Path(self.config['ELECTRICAL_PREPARATION_JSON']).read_text())
        names = manifest['affected_nets']
        if not names or any(any(c in n for c in '{}\n\r') for n in names):
            raise ValueError('Invalid affected net list')
        nets = ' '.join('{' + n + '}' for n in names)
        text = '''source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
set_thread_count 4
'''
        text += f'set eco_nets [list {nets}]\n'
        text += '''foreach name $eco_nets {
    set net [[ord::get_db_block] findNet $name]
    if {$net == "NULL"} {error "Affected net not found: $name"}
    grt::add_net_to_route $net
}
''' 
        text += '''source $::env(SCRIPTS_DIR)/openroad/common/grt.tcl
write_views
'''
        target = Path(self.step_dir) / 'preserved-route-grt.tcl'
        target.write_text(text)
        return str(target)
