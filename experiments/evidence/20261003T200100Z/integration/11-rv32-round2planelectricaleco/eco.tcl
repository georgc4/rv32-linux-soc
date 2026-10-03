set eco_movable {}
replace_cell {_24604_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_24604_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_335/DIODE} {_14603_/A1} {_24605_/B} {_14588_/A1} {_14421_/A1}] -location {248.308 208.198} -buffer_name {ci_eco_0001} -net_name {ci_eco_0001_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(1) [get_property $created full_name]
lappend eco_movable $eco_name(1)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_19882_/A2} {_14541_/A0} {_14507_/A1} {_20065_/A1} {_19789_/A1} "$eco_name(1)/A"] -location {225.216 194.611} -buffer_name {ci_eco_0002} -net_name {ci_eco_0002_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(2) [get_property $created full_name]
lappend eco_movable $eco_name(2)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(2)/A"] -location {252.096 140.078} -buffer_name {ci_eco_0003} -net_name {ci_eco_0003_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(3) [get_property $created full_name]
lappend eco_movable $eco_name(3)
replace_cell {_28485_} {sky130_fd_sc_hd__dfrtp_4}
estimate_parasitics -placement
lappend eco_movable {_28485_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_15172_/A} {_15173_/A} {_19918_/A1} {ANTENNA_372/DIODE}] -location {275.018 99.472} -buffer_name {ci_eco_0004} -net_name {ci_eco_0004_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(4) [get_property $created full_name]
lappend eco_movable $eco_name(4)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_23377_/A} {_17711_/A1}] -location {355.874 141.501} -buffer_name {ci_eco_0005} -net_name {ci_eco_0005_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(5) [get_property $created full_name]
lappend eco_movable $eco_name(5)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(5)/A" {_23465_/A0} {_15880_/A0} {_25213_/A1}] -location {371.289 141.501} -buffer_name {ci_eco_0006} -net_name {ci_eco_0006_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(6) [get_property $created full_name]
lappend eco_movable $eco_name(6)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(4)/A" "$eco_name(6)/A"] -location {330.591 130.614} -buffer_name {ci_eco_0007} -net_name {ci_eco_0007_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(7) [get_property $created full_name]
lappend eco_movable $eco_name(7)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(7)/A"] -location {379.319 155.838} -buffer_name {ci_eco_0008} -net_name {ci_eco_0008_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(8) [get_property $created full_name]
lappend eco_movable $eco_name(8)
