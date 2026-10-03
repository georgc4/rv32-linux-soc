set eco_movable {}
replace_cell {_24569_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_24569_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {_24619_/A} {_24768_/A} {_24675_/B1} {_14572_/A} {_14502_/A}] -location {265.640 94.025} -buffer_name {ci_eco_0001} -net_name {ci_eco_0001_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(1) [get_property $created full_name]
lappend eco_movable $eco_name(1)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24810_/A} {_24723_/A} {_24974_/A} {_24961_/B1} {_24625_/B1} "$eco_name(1)/A"] -location {244.250 94.025} -buffer_name {ci_eco_0002} -net_name {ci_eco_0002_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(2) [get_property $created full_name]
lappend eco_movable $eco_name(2)
