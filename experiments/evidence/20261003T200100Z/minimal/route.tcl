read_liberty /pdk/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_db /work/build/drc-marker-fix/minimal/prepared.odb
read_sdc /work/build/ci-37096880158/runs/wokwi/075-rv32-round2repairdetailedrouting/route-0-1/tt_um_rv32_linux_soc.sdc
set_thread_count 4
set_wire_rc -signal -layer met2
set_wire_rc -clock -layer met3
set_routing_layers -signal met1-met4 -clock met1-met4
set_global_routing_layer_adjustment * 0.3
foreach layer {li1 met1 met2 met3 met4 met5} adjustment {0.99 0 0 0 0 0} {set_global_routing_layer_adjustment $layer $adjustment}
set_macro_extension 0
foreach name [list {_05164_} {_05279_} {_10235_} {_10873_} {_11119_} {_11223_} {_13253_} {_13254_} {ci_eco_0195_net9170} {clk} {clknet_3_1_0_clk} {net5363} {net5890} {net6640} {net6888} {soc.cpu.priv_unit.medeleg\[13\]} {soc.cpu.priv_unit.time_value\[62\]} {soc.timer.mtimecmp\[62\]}] {grt::add_net_to_route [[ord::get_db_block] findNet $name]}
global_route -congestion_iterations 50 -verbose -allow_congestion
write_db /work/build/drc-marker-fix/minimal/global.odb
detailed_route -droute_end_iter 24 -or_seed 42 -verbose 1 -output_drc /work/build/drc-marker-fix/minimal/routed.drc
write_db /work/build/drc-marker-fix/minimal/routed.odb
write_def /work/build/drc-marker-fix/minimal/routed.def
