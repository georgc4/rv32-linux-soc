"""CI-only routed ECO stages, inserted after the first extracted STA pass."""
import json
import shutil
from pathlib import Path as FilePath
from librelane.common import Path
from librelane.state import DesignFormat as DF, State
from librelane.steps import Step
from librelane.steps.openroad import (OpenROADStep, RepairDesignPostGRT, DetailedRouting,
                                     CheckAntennas, FillInsertion, RCX, STAPostPNR)
from eco_helpers import failing_pins

ROOT=FilePath(__file__).resolve().parent


def sibling(step, suffix):
    if getattr(step, 'eco_round', 1) == 2:
        if suffix == 'openroad-stapostpnr': suffix = 'rv32-repairsta'
        elif suffix.startswith('rv32-'): suffix = 'rv32-round2' + suffix[5:]
    matches=list(FilePath(step.step_dir).parent.glob('*-'+suffix))
    if len(matches)!=1:raise RuntimeError('Missing/ambiguous prerequisite: '+suffix)
    return matches[0]


def run_python(step, name, *args):
    step.run_subprocess([OpenROADStep.get_openroad_path(),'-exit','-python',str(ROOT/name),*map(str,args)])


@Step.factory.register()
class PlanElectricalECO(Step):
    id='RV32.PlanElectricalECO';name='Plan ECO from extracted corner reports'
    inputs=[DF.ODB];outputs=[DF.ODB]
    def run(self,state_in,**kwargs):
        sta=sibling(self,'openroad-stapostpnr');pins=set()
        config=json.loads((sta/'config.json').read_text())
        corners=config['STA_CORNERS']
        if len(corners)!=9:raise RuntimeError('Expected nine pre-ECO signoff corners')
        for corner in corners:
            report=sta/corner/'checks.rpt'
            pins.update(failing_pins(report.read_text()))
        out=FilePath(self.step_dir);original=out/'original.odb'
        shutil.copyfile(state_in[DF.ODB],original)
        pinfile=out/'failing-pins.json';pinfile.write_text(json.dumps(sorted(pins),indent=2)+'\n')
        run_python(self,'plan_eco.py','--odb',original,'--pins',pinfile,'--output',out/'eco.tcl')
        return {DF.ODB:Path(str(original))},{'rv32__eco__target_pins':len(pins)}


@Step.factory.register()
class ApplyElectricalECO(RepairDesignPostGRT):
    id='RV32.ApplyElectricalECO';name='Apply and legalize targeted electrical ECO'
    def get_script_path(self):
        eco=sibling(self,'rv32-planelectricaleco')/'eco.tcl'
        text='''source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
# Keep boundary decaps; remove only the flow's reinsertable filler instances.
foreach inst [[ord::get_db_block] getInsts] {
    if {[string match FILLER_* [$inst getName]]} {odb::dbInst_destroy $inst}
}
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
estimate_parasitics -placement
'''+f'source {{{eco}}}\n'+'''
foreach inst [[ord::get_db_block] getInsts] {
    if {[$inst getName] in $eco_movable} {
        $inst setPlacementStatus PLACED
    } else {
        $inst setPlacementStatus LOCKED
    }
}
detailed_placement
check_placement -verbose
write_views
'''
        p=FilePath(self.step_dir)/'apply-eco.tcl';p.write_text(text);return str(p)


@Step.factory.register()
class PrepareECONeighborhood(Step):
    id='RV32.PrepareECONeighborhood';name='Unlock local ECO routing neighborhood'
    inputs=[DF.ODB];outputs=[DF.ODB]
    def run(self,state_in,**kwargs):
        out=FilePath(self.step_dir);original=sibling(self,'rv32-planelectricaleco')/'original.odb'
        # The 37-net CI fixture needs 58.85% with 20/5 um halos. Keep those
        # halos and bound this distributed-repair trial explicitly at 65%.
        halos=['--cell-halo-um','5','--route-halo-um','1'] if getattr(self,'eco_round',1)==2 else []
        run_python(self,'prepare_eco_routes.py','--original',original,'--eco',state_in[DF.ODB],'--output-dir',out,
                   '--max-editable-fraction','0.65',*halos)
        run_python(self,'audit_eco.py','--odb',out/'prepared.odb','--manifest',out/'preservation.json','--output',out/'pre-route-audit.json')
        m=json.loads((out/'preservation.json').read_text())
        return {DF.ODB:Path(str(out/'prepared.odb'))},{'rv32__eco__editable_nets':len(m['editable_nets']),'rv32__eco__protected_nets':len(m['protected_nets']),
                'rv32__eco__ripped_nets':len(m['reroute_nets']),
                'rv32__eco__retained_editable_nets':len(m['retained_editable_nets'])}


@Step.factory.register()
class RouteECONeighborhood(RepairDesignPostGRT):
    id='RV32.RouteECONeighborhood';name='Global-route the expanded ECO neighborhood'
    def get_script_path(self):
        manifest=self.manifest if hasattr(self,'manifest') else sibling(self,'rv32-prepareeconeighborhood')/'preservation.json'
        m=json.loads(FilePath(manifest).read_text())
        names=self.nets_to_route if hasattr(self,'nets_to_route') else m['editable_nets']
        if any(any(c in n for c in '{}\n\r') or n.endswith('\\') for n in names):raise ValueError('Unsupported net identifier')
        nets=' '.join('{'+n+'}' for n in names)
        text='''source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
set_thread_count 4
'''+f'set eco_nets [list {nets}]\n'+'''
foreach name $eco_nets {
    set net [[ord::get_db_block] findNet $name]
    if {$net == "NULL"} {error "ECO net not found: $name"}
    grt::add_net_to_route $net
}
if {[llength $eco_nets] > 0} {
    # Diagnostic coarse overflow is allowed only here; final DRC remains a gate.
    set ::env(GRT_ALLOW_CONGESTION) 1
    source $::env(SCRIPTS_DIR)/openroad/common/grt.tcl
}
write_views
'''
        p=FilePath(self.step_dir)/'route-neighborhood.tcl';p.write_text(text);return str(p)


def guarded_script(step, original):
    names=json.loads(FilePath(step.manifest).read_text())['protected_nets']
    if any(any(c in n for c in '{}\n\r') or n.endswith('\\') for n in names):
        raise ValueError('Unsupported protected net identifier')
    nets=' '.join('{'+n+'}' for n in names)
    text=f'source {{{ROOT / "antenna_guard.tcl"}}}\n'
    text+=f'rv32_antenna_guard::install [list {nets}]\n'
    text+=f'source {{{original}}}\n'
    path=FilePath(step.step_dir)/'guarded.tcl';path.write_text(text)
    return str(path)


class _FreshRoutePass(DetailedRouting):
    id='RV32.FreshRoutePass'
    def get_script_path(self):
        return guarded_script(self,super().get_script_path())


class _FreshAntennaPass(DetailedRouting):
    id='RV32.FreshAntennaPass'
    def get_script_path(self):
        return guarded_script(self,ROOT/'repair_antennas.tcl')


@Step.factory.register()
class RepairDetailedRouting(DetailedRouting):
    id='RV32.RepairDetailedRouting';name='Route and repair antennas in fresh processes'
    config_vars=list({v.name:v for cls in (DetailedRouting,RepairDesignPostGRT,CheckAntennas) for v in cls.config_vars}.values())
    def run(self,state_in,**kwargs):
        manifest=sibling(self,'rv32-prepareeconeighborhood')/'preservation.json'
        m=json.loads(manifest.read_text())
        active=FilePath(self.step_dir)/'preservation-active.json'
        shutil.copyfile(manifest,active);manifest=active
        if not m['editable_nets']:return {},{}
        # Exercise deletion recovery and fail-closed behavior on a disposable
        # copy of this run's actual ODB before executing the real repair.
        if len(m['protected_nets']) >= 2:
            out=FilePath(self.step_dir)/'guard-tests';out.mkdir(exist_ok=True)
            names=m['protected_nets'][:2]
            if any(any(c in n for c in '{}\n\r') or n.endswith('\\') for n in names):
                raise ValueError('Unsupported protected net identifier')
            nets=' '.join('{'+n+'}' for n in names)
            text=f'read_db {{{state_in[DF.ODB]}}}\n'
            text+=f'set ::env(STEP_DIR) {{{out}}}\n'
            text+=f'source {{{ROOT / "antenna_guard.tcl"}}}\n'
            text+=f'rv32_antenna_guard::install [list {nets}]\n'
            text+='if {[catch {source {'+str(ROOT/'test_antenna_guard.tcl')+'}} message]} {puts stderr $message; exit 1}\n'
            script=out/'test.tcl';script.write_text(text)
            self.run_subprocess([OpenROADStep.get_openroad_path(),'-exit',str(script)])

        state=state_in
        limit=self.config['DRT_ANTENNA_REPAIR_ITERS']
        for index in range(limit+1):
            for attempt in range(4):
                route=_FreshRoutePass(self.config,state,DRT_ANTENNA_REPAIR_ITERS=0)
                route.manifest=manifest
                state=route.start(toolbox=self.toolbox,step_dir=str(FilePath(self.step_dir)/f'route-{index}-{attempt}'),_no_rule=True)
                audit=FilePath(self.step_dir)/f'audit-{index}-{attempt}.json'
                run_python(self,'audit_eco.py','--odb',state[DF.ODB],'--manifest',manifest,
                           '--output',audit,'--report-route-contacts')
                report=json.loads(audit.read_text())
                if report['status']=='pass':break
                if not report.get('contacts') or attempt==3:
                    raise RuntimeError('Unresolved physical route contacts; see '+str(audit))
                out=FilePath(self.step_dir)/f'contact-repair-{index}-{attempt}'
                run_python(self,'expand_route_contacts.py','--odb',state[DF.ODB],
                           '--manifest',manifest,'--contacts',audit,'--output-dir',out)
                shutil.copyfile(out/'preservation.json',manifest)
                state=State(state,overrides={DF.ODB:Path(str(out/'prepared.odb'))},metrics=state.metrics)
                grt=RouteECONeighborhood(self.config,state)
                grt.manifest=manifest
                grt.nets_to_route=json.loads((out/'reroute-nets.json').read_text())
                state=grt.start(toolbox=self.toolbox,step_dir=str(out/'global-route'),_no_rule=True)
            check=CheckAntennas(self.config,state)
            state=check.start(toolbox=self.toolbox,step_dir=str(FilePath(self.step_dir)/f'antenna-check-{index}'),_no_rule=True)
            count=state.metrics.get('route__antenna_violation__count')
            if count is None:raise RuntimeError('Missing fresh antenna-check result')
            if count==0 or index==limit:break
            if self.config['DIODE_CELL'] is None:raise RuntimeError('Antenna repair needs a diode cell')
            repair=_FreshAntennaPass(self.config,state)
            repair.manifest=manifest
            state=repair.start(toolbox=self.toolbox,step_dir=str(FilePath(self.step_dir)/f'antenna-repair-{index+1}'),_no_rule=True)
        views={key:state[key] for key in state
               if state_in.get(key)!=state.get(key) and DF.factory.get(key) in self.outputs}
        metrics={key:state.metrics[key] for key in state.metrics
                 if state_in.metrics.get(key)!=state.metrics.get(key)}
        return views,metrics


@Step.factory.register()
class AuditECORoutes(Step):
    id='RV32.AuditECORoutes';name='Audit preserved geometry and ECO connectivity'
    inputs=[DF.ODB];outputs=[]
    def run(self,state_in,**kwargs):
        out=FilePath(self.step_dir)/'audit.json'
        run_python(self,'audit_eco.py','--odb',state_in[DF.ODB],'--manifest',sibling(self,'rv32-repairdetailedrouting')/'preservation-active.json','--output',out)
        return {},{'rv32__eco__preservation_pass':1}


def derived(identifier,base):
    cls=type(identifier.split('.')[-1],(base,),{'id':identifier,'__module__':__name__})
    return Step.factory.register()(cls)


ECO_STEPS=[PlanElectricalECO,ApplyElectricalECO,PrepareECONeighborhood,RouteECONeighborhood,
           RepairDetailedRouting,AuditECORoutes,
           derived('RV32.RepairCheckAntennas',CheckAntennas),
           derived('RV32.RepairDRC',Step.factory.get('Checker.TrDRC')),
           derived('RV32.RepairDisconnectedPins',Step.factory.get('Odb.ReportDisconnectedPins')),
           derived('RV32.RepairCheckDisconnectedPins',Step.factory.get('Checker.DisconnectedPins')),
           derived('RV32.RepairFillInsertion',FillInsertion),
           derived('RV32.RepairRCX',RCX),
           derived('RV32.RepairSTA',STAPostPNR)]


# A bounded second round handles violations created on neighboring rerouted nets.
# It consumes this run's first-round extracted reports, never checkpoint names.
ECO_STEPS_ROUND2=[]
for base in ECO_STEPS:
    identifier='RV32.Round2'+base.id.split('.')[-1]
    cls=type(identifier.split('.')[-1],(base,),
             {'id':identifier,'eco_round':2,'__module__':__name__})
    ECO_STEPS_ROUND2.append(Step.factory.register()(cls))
