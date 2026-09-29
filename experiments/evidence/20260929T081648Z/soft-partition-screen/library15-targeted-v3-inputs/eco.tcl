if {[[$::block findInst _25583_] getMaster] == "NULL"} {error "Missing driver _25583_"}
if {[[[$::block findInst _25583_] getMaster] getName] ne "sky130_fd_sc_hd__nor2_2"} {error "Driver identity changed: _25583_"}
replace_cell _25583_ sky130_fd_sc_hd__nor2_4
estimate_parasitics -placement
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_15176_/C1} -location {283.208 83.887} -buffer_name {eco_lib15_b4f70784d3_2} -net_name {eco_lib15_b4f70784d3_2_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_b4f70784d3_2) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_b4f70784d3_2)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_b4f70784d3_2)/A"] -location {333.910 90.055} -buffer_name {eco_lib15_b4f70784d3_1} -net_name {eco_lib15_b4f70784d3_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_b4f70784d3_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_b4f70784d3_1)"
if {[[$::block findInst _26497_] getMaster] == "NULL"} {error "Missing driver _26497_"}
if {[[[$::block findInst _26497_] getMaster] getName] ne "sky130_fd_sc_hd__a211o_2"} {error "Driver identity changed: _26497_"}
replace_cell _26497_ sky130_fd_sc_hd__a211o_4
estimate_parasitics -placement
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_26504_/A2} -location {355.190 56.498} -buffer_name {eco_lib15_46eee729a7_2} -net_name {eco_lib15_46eee729a7_2_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_46eee729a7_2) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_46eee729a7_2)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_46eee729a7_2)/A"] -location {284.649 54.572} -buffer_name {eco_lib15_46eee729a7_1} -net_name {eco_lib15_46eee729a7_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_46eee729a7_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_46eee729a7_1)"
if {[[$::block findInst _26205_] getMaster] == "NULL"} {error "Missing driver _26205_"}
if {[[[$::block findInst _26205_] getMaster] getName] ne "sky130_fd_sc_hd__or3_2"} {error "Driver identity changed: _26205_"}
replace_cell _26205_ sky130_fd_sc_hd__or3_4
estimate_parasitics -placement
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_26214_/A2} -location {364.100 53.034} -buffer_name {eco_lib15_c952639915_2} -net_name {eco_lib15_c952639915_2_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_c952639915_2) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_c952639915_2)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_c952639915_2)/A"] -location {298.787 50.252} -buffer_name {eco_lib15_c952639915_1} -net_name {eco_lib15_c952639915_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_c952639915_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_c952639915_1)"
if {[[$::block findInst _25685_] getMaster] == "NULL"} {error "Missing driver _25685_"}
if {[[[$::block findInst _25685_] getMaster] getName] ne "sky130_fd_sc_hd__nor2_2"} {error "Driver identity changed: _25685_"}
replace_cell _25685_ sky130_fd_sc_hd__nor2_4
estimate_parasitics -placement
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_15238_/B1} -location {253.687 81.807} -buffer_name {eco_lib15_7473a2883a_2} -net_name {eco_lib15_7473a2883a_2_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_7473a2883a_2) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_7473a2883a_2)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_7473a2883a_2)/A"] -location {314.089 89.015} -buffer_name {eco_lib15_7473a2883a_1} -net_name {eco_lib15_7473a2883a_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_7473a2883a_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_7473a2883a_1)"
if {[[$::block findInst _26547_] getMaster] == "NULL"} {error "Missing driver _26547_"}
if {[[[$::block findInst _26547_] getMaster] getName] ne "sky130_fd_sc_hd__or2_2"} {error "Driver identity changed: _26547_"}
replace_cell _26547_ sky130_fd_sc_hd__or2_4
estimate_parasitics -placement
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_15759_/B1_N} -location {177.988 42.331} -buffer_name {eco_lib15_0cc3dbbd89_2} -net_name {eco_lib15_0cc3dbbd89_2_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_0cc3dbbd89_2) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_0cc3dbbd89_2)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_0cc3dbbd89_2)/A"] -location {236.395 44.960} -buffer_name {eco_lib15_0cc3dbbd89_1} -net_name {eco_lib15_0cc3dbbd89_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_0cc3dbbd89_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_0cc3dbbd89_1)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_26548_/A2} -location {353.354 55.593} -buffer_name {eco_lib15_ae43b11cad_1} -net_name {eco_lib15_ae43b11cad_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_ae43b11cad_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_ae43b11cad_1)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_26570_/B1} -location {353.880 57.215} -buffer_name {eco_lib15_6f3b2e8a5c_1} -net_name {eco_lib15_6f3b2e8a5c_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_6f3b2e8a5c_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_6f3b2e8a5c_1)"
if {[[$::block findInst _22420_] getMaster] == "NULL"} {error "Missing driver _22420_"}
if {[[[$::block findInst _22420_] getMaster] getName] ne "sky130_fd_sc_hd__inv_2"} {error "Driver identity changed: _22420_"}
replace_cell _22420_ sky130_fd_sc_hd__inv_4
estimate_parasitics -placement
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins {_24896_/A2} -location {331.252 63.741} -buffer_name {eco_lib15_6331d0f588_3} -net_name {eco_lib15_6331d0f588_3_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_6331d0f588_3) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_6331d0f588_3)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_6331d0f588_3)/A"] -location {407.829 63.761} -buffer_name {eco_lib15_6331d0f588_2} -net_name {eco_lib15_6331d0f588_2_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_6331d0f588_2) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_6331d0f588_2)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list "$eco_actual(eco_lib15_6331d0f588_2)/A"] -location {484.406 63.782} -buffer_name {eco_lib15_6331d0f588_1} -net_name {eco_lib15_6331d0f588_1_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_6331d0f588_1) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_6331d0f588_1)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__clkbuf_16} -load_pins {clkbuf_3_0_0_clk/A clkbuf_3_1_0_clk/A clkbuf_3_2_0_clk/A clkbuf_3_3_0_clk/A} -location {411.067 262.530} -buffer_name {eco_lib15_clock_west} -net_name {eco_lib15_clock_west_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_clock_west) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_clock_west)"
set eco_created [insert_buffer -buffer_cell {sky130_fd_sc_hd__clkbuf_16} -load_pins {clkbuf_3_4_0_clk/A clkbuf_3_5_0_clk/A clkbuf_3_6_0_clk/A clkbuf_3_7_0_clk/A} -location {451.067 262.530} -buffer_name {eco_lib15_clock_east} -net_name {eco_lib15_clock_east_net}]
if {$eco_created == "NULL"} {error "Buffer insertion returned NULL"}
set eco_actual(eco_lib15_clock_east) [get_property $eco_created full_name]
puts "ECO inserted $eco_actual(eco_lib15_clock_east)"
