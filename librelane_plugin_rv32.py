"""Reproduce the four-part placement experiment from a clean RTL checkout."""
import json
import sys
from pathlib import Path as FilePath
from librelane.common import Path
from librelane.state import DesignFormat
from librelane.steps import Step
from librelane.steps.openroad import OpenROADStep
from librelane.flows import Flow, SequentialFlow
from librelane.flows.classic import Classic

ROOT = FilePath(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'physical'))
from librelane_eco_steps import ECO_STEPS, ECO_STEPS_ROUND2, ECO_STEPS_ROUND3

@Step.factory.register()
class PartitionDesign(OpenROADStep):
    id = 'RV32.PartitionDesign'
    name = 'Partition connectivity with TritonPart'
    inputs = [DesignFormat.ODB]
    outputs = [DesignFormat.ODB]

    def get_script_path(self):
        return str(ROOT / 'physical/partition.tcl')

@Step.factory.register()
class SeedPlacement(Step):
    id = 'RV32.SeedPlacement'
    name = 'Seed movable connectivity groups'
    inputs = [DesignFormat.ODB]
    outputs = [DesignFormat.ODB]

    def run(self, state_in, **kwargs):
        source = FilePath(state_in[DesignFormat.ODB])
        partition = source.parent / 'partition.txt'
        if not partition.is_file():
            raise RuntimeError('Missing TritonPart result; refusing unpartitioned placement')
        output = FilePath(self.step_dir) / 'seeded.odb'
        self.run_subprocess([
            OpenROADStep.get_openroad_path(), '-exit', '-python',
            str(ROOT / 'physical/seed_soft_partitions.py'),
            '--odb', str(source), '--partition', str(partition), '--output', str(output),
        ])
        report = json.loads(FilePath(str(output) + '.json').read_text())
        return {DesignFormat.ODB: Path(str(output))}, {
            'rv32__partition__movable_instances': report['movable_instances'],
            'rv32__partition__groups': len(report['counts']),
        }

@Flow.factory.register()
class RV32Partitioned(SequentialFlow):
    name = 'RV32Partitioned'
    Steps = []
    for step in Classic.Steps:
        if step.id == 'OpenROAD.GlobalPlacement':
            Steps.extend([PartitionDesign, SeedPlacement])
        Steps.append(step)
        if step.id == "OpenROAD.STAPostPNR":
            Steps.extend(ECO_STEPS)
            Steps.extend(ECO_STEPS_ROUND2)
            Steps.extend(ECO_STEPS_ROUND3)
    config_vars = Classic.config_vars
    gating_config_vars = Classic.gating_config_vars
