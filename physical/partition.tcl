source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
read_current_odb
triton_part_design -num_parts 4 -balance_constraint 5 -timing_aware_flag false -seed 1 -num_initial_solutions 10 -num_best_initial_solutions 3 -global_net_threshold 64 -solution_file $::env(STEP_DIR)/partition.txt
write_views
