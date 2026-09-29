set_cmd_units -time ns -capacitance pF -current mA -voltage V -resistance kOhm -distance um
set sta_report_default_digits 6
define_corners nom_tt_025C_1v80
read_liberty -corner nom_tt_025C_1v80 /Users/cgeorges/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog {/Users/cgeorges/rv32-linux-soc/build/experiments/soft-partition-screen/four-part-qualification/runs/wokwi/13-openroad-fillinsertion/tt_um_rv32_linux_soc.nl.v}
link_design tt_um_rv32_linux_soc
read_sdc {/Users/cgeorges/rv32-linux-soc/build/experiments/soft-partition-screen/four-part-qualification/runs/wokwi/13-openroad-fillinsertion/tt_um_rv32_linux_soc.sdc}
set_propagated_clock [all_clocks]
read_spef -corner nom_tt_025C_1v80 {/Users/cgeorges/rv32-linux-soc/build/experiments/soft-partition-screen/four-part-qualification/runs/wokwi/15-openroad-rcx/nom/tt_um_rv32_linux_soc.nom.spef}
foreach limit {0.75 1.0 1.5} {
 set_max_transition $limit [current_design]
 puts "DIAGNOSTIC transition=$limit slew_violations=[sta::max_slew_violation_count] cap_violations=[sta::max_capacitance_violation_count]"
}
report_check_types -max_slew -max_capacitance -violators -corner nom_tt_025C_1v80
exit
