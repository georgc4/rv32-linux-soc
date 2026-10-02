# Run one antenna repair in its own process. The next DRT process rebuilds its
# spatial index from the emitted ODB, including every protected FIXED path.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
source $::env(SCRIPTS_DIR)/openroad/common/set_routing_layers.tcl
source $::env(SCRIPTS_DIR)/openroad/common/set_layer_adjustments.tcl
set_thread_count $::env(DRT_THREADS)
set diode_cell [lindex [split $::env(DIODE_CELL) "/"] 0]
set args [list $diode_cell -ratio_margin $::env(GRT_ANTENNA_REPAIR_MARGIN)]
append_if_flag args GRT_ALLOW_CONGESTION -allow_congestion
append_if_flag args DRT_ANTENNA_REPAIR_JUMPER_ONLY -jumper_only
append_if_flag args DRT_ANTENNA_REPAIR_DIODE_ONLY -diode_only
log_cmd repair_antennas {*}$args
write_views
