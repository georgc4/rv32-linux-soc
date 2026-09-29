read_liberty /Users/cgeorges/.volare/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db {/Users/cgeorges/rv32-linux-soc/build/experiments/runs/f91a5e108ca5-717c71a48262/pnr-stage/runs/wokwi/27-odb-applydeftemplate/tt_um_rv32_linux_soc.odb}
triton_part_design -num_parts 4 -balance_constraint 5 -timing_aware_flag false -seed 1 -num_initial_solutions 10 -num_best_initial_solutions 3 -global_net_threshold 64 -solution_file {/Users/cgeorges/rv32-linux-soc/build/experiments/soft-partition-screen/partition.txt}
exit
