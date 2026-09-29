"""Rebuild all routing after an extracted-RC electrical ECO."""
from librelane.steps import Step
from librelane_plugin_extracted_repair import ExtractedRepair


@Step.factory.register()
class ExtractedFullRoute(ExtractedRepair):
    id = 'Electrical.ExtractedFullRoute'

    def get_script_path(self):
        path = super().get_script_path()
        from pathlib import Path
        target = Path(path)
        text = target.read_text()
        anchor = 'read_current_odb\nremove_fillers'
        if text.count(anchor) != 1:
            raise RuntimeError('Unexpected ECO initialization')
        # RC evidence is retained in the external SPEFs. Old detailed wires must
        # not consume routing capacity when rebuilding routes for the ECO.
        text = text.replace(anchor, anchor + '''
set removed_signal_wires 0
foreach net [$::block getNets] {
    if {[$net getSigType] in {POWER GROUND}} {continue}
    set wire [$net getWire]
    if {$wire != "NULL"} {
        odb::dbWire_destroy $wire
        incr removed_signal_wires
    }
}
puts "Discarded $removed_signal_wires old signal/clock routes for full rerouting"
''')
        # Initialize the incremental parasitic updater before overriding its
        # initial estimates with the measured input-netlist RC. Modified nets
        # then get routing estimates rather than falling back to wire loads.
        text = text.replace('read_spef -corner',
                            'estimate_parasitics -global_routing\nread_spef -corner', 1)
        target.write_text(text)
        return str(target)
