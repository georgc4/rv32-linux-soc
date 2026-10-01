read_liberty /pdk/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /work/build/ci-36811470893/runs/wokwi/58-rv32-planelectricaleco/original.odb
read_sdc /work/build/ci-36811470893/runs/wokwi/54-openroad-fillinsertion/tt_um_rv32_linux_soc.sdc
remove_fillers
# Placement/connectivity diagnostic only. Final RC and nine-corner STA run in CI.
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3
estimate_parasitics -placement
source /work/build/shared-eco-plan/eco.tcl
foreach inst [[ord::get_db_block] getInsts] {
    if {[$inst getName] ni $eco_movable} {$inst setPlacementStatus LOCKED}
}
detailed_placement
check_placement -verbose
write_db /work/build/shared-eco-plan/applied.odb
write_verilog /work/build/shared-eco-plan/applied.v
