import odb,json
from pathlib import Path
root=Path(__file__).resolve().parent
state=json.loads((root.parent/'four-part-qualification/runs/wokwi/15-openroad-rcx/state_out.json').read_text())
a=odb.dbDatabase.create();odb.read_db(a,state['odb']);old=a.getChip().getBlock()
b=odb.dbDatabase.create();odb.read_db(b,str(root/'dry-eco.odb'));new=b.getChip().getBlock()
changed={'_25583_','_26497_','_26205_','_25685_','_26547_','_22420_'}
def drivers(net,depth=0):
 if net is None:return ()
 assert depth<30
 result=[]
 for t in net.getITerms():
  if t.getIoType()!='OUTPUT':continue
  i=t.getInst()
  if i.getName().startswith('eco_lib15_'):
   assert i.getMaster().getName() in ['sky130_fd_sc_hd__buf_4','sky130_fd_sc_hd__clkbuf_16']
   result.extend(drivers(i.findITerm('A').getNet(),depth+1))
  else:result.append(i.getName()+'/'+t.getMTerm().getName())
 for t in net.getBTerms():
  if t.getIoType()=='INPUT':result.append('PORT:'+t.getName())
 return tuple(sorted(set(result)))
checked=0
for i in old.getInsts():
 j=new.findInst(i.getName())
 if j is None:
  assert i.getName().startswith('FILLER_'),i.getName()
  continue
 if i.getName() in changed:assert j.getMaster().getName()==i.getMaster().getName().removesuffix('_2')+'_4'
 else:assert j.getMaster().getName()==i.getMaster().getName()
 for t in i.getITerms():
  if t.getIoType()!='INPUT' or t.getSigType() in ['POWER','GROUND']:continue
  u=j.findITerm(t.getMTerm().getName())
  assert drivers(t.getNet())==drivers(u.getNet()),(i.getName(),t.getMTerm().getName())
  checked+=1
for t in old.getBTerms():
 u=new.findBTerm(t.getName());assert u
 if t.getIoType()=='OUTPUT':assert drivers(t.getNet())==drivers(u.getNet())
extra=[i for i in new.getInsts() if i.getName().startswith('eco_lib15_')]
assert len(extra)==17
r={'status':'pass','checked_original_input_pins':checked,'equivalent_family_resizes':6,'noninverting_buffers':17,'scope':'Static driver-connectivity equivalence, stripping added noninverting buffers; not timing or physical signoff'}
(root/'connectivity-verification.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
