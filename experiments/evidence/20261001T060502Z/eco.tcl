set eco_movable {}
replace_cell {_25213_} {sky130_fd_sc_hd__a22oi_4}
estimate_parasitics -placement
lappend eco_movable {_25213_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_13661_/A} {_13928_/A} {_14127_/B} {_25231_/A1} {_25232_/B} {_26750_/B}] -location {538.892 263.263} -buffer_name {ci_eco_0001} -net_name {ci_eco_0001_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(1) [get_property $created full_name]
lappend eco_movable $eco_name(1)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(1)/A"] -location {493.447 235.736} -buffer_name {ci_eco_0002} -net_name {ci_eco_0002_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(2) [get_property $created full_name]
lappend eco_movable $eco_name(2)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(2)/A"] -location {448.003 208.210} -buffer_name {ci_eco_0003} -net_name {ci_eco_0003_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(3) [get_property $created full_name]
lappend eco_movable $eco_name(3)
replace_cell {_25230_} {sky130_fd_sc_hd__o22ai_4}
estimate_parasitics -placement
lappend eco_movable {_25230_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {_13928_/B} {ANTENNA_6/DIODE} {_26750_/C} {_13661_/B} {ANTENNA_2/DIODE}] -location {592.131 293.660} -buffer_name {ci_eco_0004} -net_name {ci_eco_0004_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(4) [get_property $created full_name]
lappend eco_movable $eco_name(4)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_5/DIODE} {ANTENNA_4/DIODE} {_25231_/B1} {_14127_/A} {ANTENNA_3/DIODE} "$eco_name(4)/A"] -location {584.200 290.880} -buffer_name {ci_eco_0005} -net_name {ci_eco_0005_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(5) [get_property $created full_name]
lappend eco_movable $eco_name(5)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(5)/A"] -location {538.744 255.255} -buffer_name {ci_eco_0006} -net_name {ci_eco_0006_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(6) [get_property $created full_name]
lappend eco_movable $eco_name(6)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(6)/A"] -location {493.289 219.630} -buffer_name {ci_eco_0007} -net_name {ci_eco_0007_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(7) [get_property $created full_name]
lappend eco_movable $eco_name(7)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(7)/A"] -location {447.833 184.005} -buffer_name {ci_eco_0008} -net_name {ci_eco_0008_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(8) [get_property $created full_name]
lappend eco_movable $eco_name(8)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(8)/A"] -location {402.378 148.380} -buffer_name {ci_eco_0009} -net_name {ci_eco_0009_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(9) [get_property $created full_name]
lappend eco_movable $eco_name(9)
replace_cell {_25435_} {sky130_fd_sc_hd__nor3_4}
estimate_parasitics -placement
lappend eco_movable {_25435_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {_26574_/B2} {_25655_/B2} {place5712/A} {_25594_/B2} {place5710/A}] -location {476.627 130.560} -buffer_name {ci_eco_0010} -net_name {ci_eco_0010_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(10) [get_property $created full_name]
lappend eco_movable $eco_name(10)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_25436_/B2} {_25701_/B2} {_26014_/B2} {_25842_/B2} {_25978_/B2} "$eco_name(10)/A"] -location {423.394 151.829} -buffer_name {ci_eco_0011} -net_name {ci_eco_0011_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(11) [get_property $created full_name]
lappend eco_movable $eco_name(11)
replace_cell {_26751_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_26751_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_26758_/S} {_26754_/S} {place5292/A} {place5293/A}] -location {637.083 295.010} -buffer_name {ci_eco_0012} -net_name {ci_eco_0012_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(12) [get_property $created full_name]
lappend eco_movable $eco_name(12)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_26752_/S} {_13386_/S}] -location {693.845 255.680} -buffer_name {ci_eco_0013} -net_name {ci_eco_0013_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(13) [get_property $created full_name]
lappend eco_movable $eco_name(13)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(13)/A" {_13390_/S} {place5294/A} {_26774_/S}] -location {744.445 254.729} -buffer_name {ci_eco_0014} -net_name {ci_eco_0014_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(14) [get_property $created full_name]
lappend eco_movable $eco_name(14)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(12)/A"] -location {677.333 286.375} -buffer_name {ci_eco_0015} -net_name {ci_eco_0015_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(15) [get_property $created full_name]
lappend eco_movable $eco_name(15)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(15)/A" "$eco_name(14)/A"] -location {717.583 277.740} -buffer_name {ci_eco_0016} -net_name {ci_eco_0016_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(16) [get_property $created full_name]
lappend eco_movable $eco_name(16)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(16)/A"] -location {672.307 287.621} -buffer_name {ci_eco_0017} -net_name {ci_eco_0017_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(17) [get_property $created full_name]
lappend eco_movable $eco_name(17)
replace_cell {_13662_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_13662_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {place5338/A} {_13665_/S} {_13672_/S} {_13686_/S}] -location {675.264 320.960} -buffer_name {ci_eco_0018} -net_name {ci_eco_0018_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(18) [get_property $created full_name]
lappend eco_movable $eco_name(18)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_13669_/S} {_13688_/S} {_13663_/S} {place5337/A} "$eco_name(18)/A"] -location {678.762 283.830} -buffer_name {ci_eco_0019} -net_name {ci_eco_0019_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(19) [get_property $created full_name]
lappend eco_movable $eco_name(19)
replace_cell {_13895_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_13895_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_13909_/S} {_13920_/S} {_13897_/S} {place5263/A}] -location {587.355 433.730} -buffer_name {ci_eco_0020} -net_name {ci_eco_0020_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(20) [get_property $created full_name]
lappend eco_movable $eco_name(20)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {place5262/A} {_13915_/S} {_13914_/S} "$eco_name(20)/A"] -location {589.713 346.726} -buffer_name {ci_eco_0021} -net_name {ci_eco_0021_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(21) [get_property $created full_name]
lappend eco_movable $eco_name(21)
replace_cell {_14227_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_14227_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {place5299/A} {place5301/A}] -location {660.362 368.370} -buffer_name {ci_eco_0022} -net_name {ci_eco_0022_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(22) [get_property $created full_name]
lappend eco_movable $eco_name(22)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {_14255_/S} {_14256_/S}] -location {749.735 400.790} -buffer_name {ci_eco_0023} -net_name {ci_eco_0023_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(23) [get_property $created full_name]
lappend eco_movable $eco_name(23)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(22)/A" "$eco_name(23)/A"] -location {695.043 368.370} -buffer_name {ci_eco_0024} -net_name {ci_eco_0024_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(24) [get_property $created full_name]
lappend eco_movable $eco_name(24)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {place5300/A} {_14235_/S} {_14239_/S} {_14236_/S} {_14233_/S}] -location {809.765 435.500} -buffer_name {ci_eco_0025} -net_name {ci_eco_0025_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(25) [get_property $created full_name]
lappend eco_movable $eco_name(25)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(25)/A"] -location {769.309 418.404} -buffer_name {ci_eco_0026} -net_name {ci_eco_0026_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(26) [get_property $created full_name]
lappend eco_movable $eco_name(26)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(24)/A" "$eco_name(26)/A"] -location {728.853 401.309} -buffer_name {ci_eco_0027} -net_name {ci_eco_0027_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(27) [get_property $created full_name]
lappend eco_movable $eco_name(27)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(27)/A"] -location {696.753 368.520} -buffer_name {ci_eco_0028} -net_name {ci_eco_0028_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(28) [get_property $created full_name]
lappend eco_movable $eco_name(28)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(28)/A"] -location {664.652 335.731} -buffer_name {ci_eco_0029} -net_name {ci_eco_0029_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(29) [get_property $created full_name]
lappend eco_movable $eco_name(29)
replace_cell {_14538_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_14538_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_14566_/S} {_14554_/S} {place5398/A}] -location {39.543 131.810} -buffer_name {ci_eco_0030} -net_name {ci_eco_0030_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(30) [get_property $created full_name]
lappend eco_movable $eco_name(30)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_14559_/S} {_14548_/S} {ANTENNA_296/DIODE}] -location {96.683 140.284} -buffer_name {ci_eco_0031} -net_name {ci_eco_0031_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(31) [get_property $created full_name]
lappend eco_movable $eco_name(31)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(30)/A" "$eco_name(31)/A"] -location {70.545 135.795} -buffer_name {ci_eco_0032} -net_name {ci_eco_0032_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(32) [get_property $created full_name]
lappend eco_movable $eco_name(32)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(32)/A"] -location {130.288 153.066} -buffer_name {ci_eco_0033} -net_name {ci_eco_0033_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(33) [get_property $created full_name]
lappend eco_movable $eco_name(33)
replace_cell {_20838_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20838_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21838_/A1} {_20839_/A1}] -location {104.921 327.964} -buffer_name {ci_eco_0034} -net_name {ci_eco_0034_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(34) [get_property $created full_name]
lappend eco_movable $eco_name(34)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(34)/A" {_20905_/B2} {_20921_/A1}] -location {101.959 341.564} -buffer_name {ci_eco_0035} -net_name {ci_eco_0035_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(35) [get_property $created full_name]
lappend eco_movable $eco_name(35)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(35)/A" {_22001_/A1} {_22088_/A0} {_22124_/A0} {_21476_/B} {_21097_/A0}] -location {147.594 342.624} -buffer_name {ci_eco_0036} -net_name {ci_eco_0036_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(36) [get_property $created full_name]
lappend eco_movable $eco_name(36)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(36)/A"] -location {220.214 331.278} -buffer_name {ci_eco_0037} -net_name {ci_eco_0037_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(37) [get_property $created full_name]
lappend eco_movable $eco_name(37)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(37)/A"] -location {292.835 319.932} -buffer_name {ci_eco_0038} -net_name {ci_eco_0038_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(38) [get_property $created full_name]
lappend eco_movable $eco_name(38)
replace_cell {_20846_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20846_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22019_/A1} {_20847_/A1} {_20909_/B2} {_20949_/A1}] -location {80.804 346.595} -buffer_name {ci_eco_0039} -net_name {ci_eco_0039_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(39) [get_property $created full_name]
lappend eco_movable $eco_name(39)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22128_/A0} {_21101_/A0} {_21475_/B}] -location {169.881 371.087} -buffer_name {ci_eco_0040} -net_name {ci_eco_0040_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(40) [get_property $created full_name]
lappend eco_movable $eco_name(40)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22092_/A0} {_21851_/A0}] -location {133.499 321.902} -buffer_name {ci_eco_0041} -net_name {ci_eco_0041_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(41) [get_property $created full_name]
lappend eco_movable $eco_name(41)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(39)/A" "$eco_name(41)/A" "$eco_name(40)/A"] -location {144.374 339.165} -buffer_name {ci_eco_0042} -net_name {ci_eco_0042_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(42) [get_property $created full_name]
lappend eco_movable $eco_name(42)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(42)/A"] -location {213.214 325.467} -buffer_name {ci_eco_0043} -net_name {ci_eco_0043_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(43) [get_property $created full_name]
lappend eco_movable $eco_name(43)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(43)/A"] -location {282.055 311.769} -buffer_name {ci_eco_0044} -net_name {ci_eco_0044_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(44) [get_property $created full_name]
lappend eco_movable $eco_name(44)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(44)/A"] -location {350.895 298.071} -buffer_name {ci_eco_0045} -net_name {ci_eco_0045_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(45) [get_property $created full_name]
lappend eco_movable $eco_name(45)
replace_cell {_20862_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20862_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21980_/A1} {_22119_/A0} {ANTENNA_101/DIODE} {_20863_/A1} {ANTENNA_96/DIODE} {ANTENNA_97/DIODE} {_20901_/B2}] -location {56.166 338.899} -buffer_name {ci_eco_0046} -net_name {ci_eco_0046_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(46) [get_property $created full_name]
lappend eco_movable $eco_name(46)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21821_/A} {_22083_/A0} {ANTENNA_100/DIODE} {_20948_/A0}] -location {89.388 331.658} -buffer_name {ci_eco_0047} -net_name {ci_eco_0047_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(47) [get_property $created full_name]
lappend eco_movable $eco_name(47)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_98/DIODE} {_21109_/A0}] -location {147.344 391.942} -buffer_name {ci_eco_0048} -net_name {ci_eco_0048_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(48) [get_property $created full_name]
lappend eco_movable $eco_name(48)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(47)/A" "$eco_name(48)/A" {ANTENNA_99/DIODE} {_21472_/B}] -location {161.232 333.543} -buffer_name {ci_eco_0049} -net_name {ci_eco_0049_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(49) [get_property $created full_name]
lappend eco_movable $eco_name(49)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(46)/A" "$eco_name(49)/A"] -location {138.820 333.543} -buffer_name {ci_eco_0050} -net_name {ci_eco_0050_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(50) [get_property $created full_name]
lappend eco_movable $eco_name(50)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(50)/A"] -location {198.584 324.583} -buffer_name {ci_eco_0051} -net_name {ci_eco_0051_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(51) [get_property $created full_name]
lappend eco_movable $eco_name(51)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(51)/A"] -location {258.348 315.624} -buffer_name {ci_eco_0052} -net_name {ci_eco_0052_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(52) [get_property $created full_name]
lappend eco_movable $eco_name(52)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(52)/A"] -location {318.112 306.665} -buffer_name {ci_eco_0053} -net_name {ci_eco_0053_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(53) [get_property $created full_name]
lappend eco_movable $eco_name(53)
replace_cell {_20864_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20864_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21984_/A1} {_22120_/A0} {ANTENNA_106/DIODE} {ANTENNA_102/DIODE} {_20865_/A1} {ANTENNA_103/DIODE} {_20902_/B2}] -location {39.238 333.393} -buffer_name {ci_eco_0054} -net_name {ci_eco_0054_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(54) [get_property $created full_name]
lappend eco_movable $eco_name(54)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21826_/A1} {_22084_/A0} {ANTENNA_104/DIODE} {_20955_/A0}] -location {94.673 334.565} -buffer_name {ci_eco_0055} -net_name {ci_eco_0055_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(55) [get_property $created full_name]
lappend eco_movable $eco_name(55)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21110_/A0} {ANTENNA_105/DIODE} {ANTENNA_275/DIODE} {_21472_/C}] -location {195.321 350.189} -buffer_name {ci_eco_0056} -net_name {ci_eco_0056_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(56) [get_property $created full_name]
lappend eco_movable $eco_name(56)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(54)/A" "$eco_name(55)/A" "$eco_name(56)/A"] -location {127.903 333.562} -buffer_name {ci_eco_0057} -net_name {ci_eco_0057_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(57) [get_property $created full_name]
lappend eco_movable $eco_name(57)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(57)/A"] -location {192.065 325.303} -buffer_name {ci_eco_0058} -net_name {ci_eco_0058_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(58) [get_property $created full_name]
lappend eco_movable $eco_name(58)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(58)/A"] -location {256.228 317.044} -buffer_name {ci_eco_0059} -net_name {ci_eco_0059_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(59) [get_property $created full_name]
lappend eco_movable $eco_name(59)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(59)/A"] -location {320.391 308.785} -buffer_name {ci_eco_0060} -net_name {ci_eco_0060_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(60) [get_property $created full_name]
lappend eco_movable $eco_name(60)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(60)/A"] -location {384.553 300.525} -buffer_name {ci_eco_0061} -net_name {ci_eco_0061_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(61) [get_property $created full_name]
lappend eco_movable $eco_name(61)
replace_cell {_20866_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20866_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21989_/A1} {_22121_/A0} {_22085_/A0} {_20867_/A1} {_20903_/B2}] -location {48.127 327.501} -buffer_name {ci_eco_0062} -net_name {ci_eco_0062_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(62) [get_property $created full_name]
lappend eco_movable $eco_name(62)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21829_/A1} {_20962_/A0}] -location {76.798 328.280} -buffer_name {ci_eco_0063} -net_name {ci_eco_0063_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(63) [get_property $created full_name]
lappend eco_movable $eco_name(63)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_302/DIODE} {_21472_/D} {_21111_/A0}] -location {190.199 344.471} -buffer_name {ci_eco_0064} -net_name {ci_eco_0064_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(64) [get_property $created full_name]
lappend eco_movable $eco_name(64)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(62)/A" "$eco_name(63)/A" "$eco_name(64)/A"] -location {132.624 327.501} -buffer_name {ci_eco_0065} -net_name {ci_eco_0065_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(65) [get_property $created full_name]
lappend eco_movable $eco_name(65)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(65)/A"] -location {211.768 322.192} -buffer_name {ci_eco_0066} -net_name {ci_eco_0066_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(66) [get_property $created full_name]
lappend eco_movable $eco_name(66)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(66)/A"] -location {290.912 316.882} -buffer_name {ci_eco_0067} -net_name {ci_eco_0067_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(67) [get_property $created full_name]
lappend eco_movable $eco_name(67)
replace_cell {_20868_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20868_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21915_/A1} {_22105_/A0} {_20869_/A1} {_20888_/B2}] -location {14.125 326.393} -buffer_name {ci_eco_0068} -net_name {ci_eco_0068_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(68) [get_property $created full_name]
lappend eco_movable $eco_name(68)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20912_/A1}] -location {117.700 381.472} -buffer_name {ci_eco_0069} -net_name {ci_eco_0069_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(69) [get_property $created full_name]
lappend eco_movable $eco_name(69)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21084_/A}] -location {180.508 353.051} -buffer_name {ci_eco_0070} -net_name {ci_eco_0070_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(70) [get_property $created full_name]
lappend eco_movable $eco_name(70)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21768_/A1} {_22069_/A0}] -location {88.750 316.412} -buffer_name {ci_eco_0071} -net_name {ci_eco_0071_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(71) [get_property $created full_name]
lappend eco_movable $eco_name(71)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(71)/A" "$eco_name(69)/A" "$eco_name(70)/A"] -location {124.040 329.182} -buffer_name {ci_eco_0072} -net_name {ci_eco_0072_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(72) [get_property $created full_name]
lappend eco_movable $eco_name(72)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(68)/A"] -location {62.193 327.007} -buffer_name {ci_eco_0073} -net_name {ci_eco_0073_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(73) [get_property $created full_name]
lappend eco_movable $eco_name(73)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(73)/A" "$eco_name(72)/A"] -location {110.262 327.621} -buffer_name {ci_eco_0074} -net_name {ci_eco_0074_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(74) [get_property $created full_name]
lappend eco_movable $eco_name(74)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(74)/A"] -location {180.156 318.169} -buffer_name {ci_eco_0075} -net_name {ci_eco_0075_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(75) [get_property $created full_name]
lappend eco_movable $eco_name(75)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(75)/A"] -location {250.049 308.717} -buffer_name {ci_eco_0076} -net_name {ci_eco_0076_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(76) [get_property $created full_name]
lappend eco_movable $eco_name(76)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(76)/A"] -location {319.942 299.265} -buffer_name {ci_eco_0077} -net_name {ci_eco_0077_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(77) [get_property $created full_name]
lappend eco_movable $eco_name(77)
replace_cell {_20870_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20870_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21920_/A1} {_22070_/A0} {_22106_/A0} {_20889_/B2}] -location {25.149 333.007} -buffer_name {ci_eco_0078} -net_name {ci_eco_0078_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(78) [get_property $created full_name]
lappend eco_movable $eco_name(78)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21774_/A1} {_20871_/A1}] -location {61.613 315.739} -buffer_name {ci_eco_0079} -net_name {ci_eco_0079_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(79) [get_property $created full_name]
lappend eco_movable $eco_name(79)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20919_/B} {_21084_/B}] -location {160.431 368.263} -buffer_name {ci_eco_0080} -net_name {ci_eco_0080_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(80) [get_property $created full_name]
lappend eco_movable $eco_name(80)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(78)/A" "$eco_name(79)/A" "$eco_name(80)/A"] -location {111.691 330.895} -buffer_name {ci_eco_0081} -net_name {ci_eco_0081_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(81) [get_property $created full_name]
lappend eco_movable $eco_name(81)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(81)/A"] -location {185.086 324.454} -buffer_name {ci_eco_0082} -net_name {ci_eco_0082_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(82) [get_property $created full_name]
lappend eco_movable $eco_name(82)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(82)/A"] -location {258.481 318.014} -buffer_name {ci_eco_0083} -net_name {ci_eco_0083_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(83) [get_property $created full_name]
lappend eco_movable $eco_name(83)
replace_cell {_20872_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20872_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21925_/A1} {_22071_/A0} {_22107_/A0} {_20873_/A1} {_20890_/B2}] -location {21.217 342.712} -buffer_name {ci_eco_0084} -net_name {ci_eco_0084_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(84) [get_property $created full_name]
lappend eco_movable $eco_name(84)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21778_/A1} {_20927_/A1}] -location {67.133 336.216} -buffer_name {ci_eco_0085} -net_name {ci_eco_0085_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(85) [get_property $created full_name]
lappend eco_movable $eco_name(85)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_107/DIODE}] -location {116.621 383.520} -buffer_name {ci_eco_0086} -net_name {ci_eco_0086_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(86) [get_property $created full_name]
lappend eco_movable $eco_name(86)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(85)/A" "$eco_name(86)/A" {ANTENNA_108/DIODE} {_21084_/C}] -location {131.417 336.216} -buffer_name {ci_eco_0087} -net_name {ci_eco_0087_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(87) [get_property $created full_name]
lappend eco_movable $eco_name(87)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(84)/A"] -location {66.237 339.491} -buffer_name {ci_eco_0088} -net_name {ci_eco_0088_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(88) [get_property $created full_name]
lappend eco_movable $eco_name(88)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(88)/A" "$eco_name(87)/A"] -location {111.256 336.270} -buffer_name {ci_eco_0089} -net_name {ci_eco_0089_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(89) [get_property $created full_name]
lappend eco_movable $eco_name(89)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(89)/A"] -location {184.351 323.909} -buffer_name {ci_eco_0090} -net_name {ci_eco_0090_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(90) [get_property $created full_name]
lappend eco_movable $eco_name(90)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(90)/A"] -location {257.446 311.548} -buffer_name {ci_eco_0091} -net_name {ci_eco_0091_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(91) [get_property $created full_name]
lappend eco_movable $eco_name(91)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(91)/A"] -location {330.541 299.187} -buffer_name {ci_eco_0092} -net_name {ci_eco_0092_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(92) [get_property $created full_name]
lappend eco_movable $eco_name(92)
replace_cell {_20874_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20874_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21929_/A} {_22072_/A0} {_20875_/A1} {_20891_/B2}] -location {20.752 333.373} -buffer_name {ci_eco_0093} -net_name {ci_eco_0093_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(93) [get_property $created full_name]
lappend eco_movable $eco_name(93)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20934_/A1} {_21084_/D}] -location {150.689 364.601} -buffer_name {ci_eco_0094} -net_name {ci_eco_0094_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(94) [get_property $created full_name]
lappend eco_movable $eco_name(94)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22108_/A0} {_21780_/A}] -location {91.636 318.010} -buffer_name {ci_eco_0095} -net_name {ci_eco_0095_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(95) [get_property $created full_name]
lappend eco_movable $eco_name(95)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(93)/A"] -location {65.595 331.867} -buffer_name {ci_eco_0096} -net_name {ci_eco_0096_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(96) [get_property $created full_name]
lappend eco_movable $eco_name(96)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(96)/A" "$eco_name(95)/A" "$eco_name(94)/A"] -location {110.439 330.361} -buffer_name {ci_eco_0097} -net_name {ci_eco_0097_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(97) [get_property $created full_name]
lappend eco_movable $eco_name(97)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(97)/A"] -location {183.738 323.558} -buffer_name {ci_eco_0098} -net_name {ci_eco_0098_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(98) [get_property $created full_name]
lappend eco_movable $eco_name(98)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(98)/A"] -location {257.038 316.754} -buffer_name {ci_eco_0099} -net_name {ci_eco_0099_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(99) [get_property $created full_name]
lappend eco_movable $eco_name(99)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(99)/A"] -location {330.337 309.950} -buffer_name {ci_eco_0100} -net_name {ci_eco_0100_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(100) [get_property $created full_name]
lappend eco_movable $eco_name(100)
replace_cell {_20876_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20876_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20892_/B2} {_22073_/A0} {_20877_/A1}] -location {46.074 365.485} -buffer_name {ci_eco_0101} -net_name {ci_eco_0101_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(101) [get_property $created full_name]
lappend eco_movable $eco_name(101)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21788_/A1} {_21936_/A1} {_22109_/A0} "$eco_name(101)/A"] -location {46.074 324.920} -buffer_name {ci_eco_0102} -net_name {ci_eco_0102_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(102) [get_property $created full_name]
lappend eco_movable $eco_name(102)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20941_/A1} {_21083_/A} {ANTENNA_109/DIODE} {ANTENNA_110/DIODE} {ANTENNA_111/DIODE} {ANTENNA_112/DIODE}] -location {141.717 347.504} -buffer_name {ci_eco_0103} -net_name {ci_eco_0103_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(103) [get_property $created full_name]
lappend eco_movable $eco_name(103)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(102)/A" "$eco_name(103)/A"] -location {114.706 329.130} -buffer_name {ci_eco_0104} -net_name {ci_eco_0104_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(104) [get_property $created full_name]
lappend eco_movable $eco_name(104)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(104)/A"] -location {181.232 323.443} -buffer_name {ci_eco_0105} -net_name {ci_eco_0105_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(105) [get_property $created full_name]
lappend eco_movable $eco_name(105)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(105)/A"] -location {247.758 317.755} -buffer_name {ci_eco_0106} -net_name {ci_eco_0106_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(106) [get_property $created full_name]
lappend eco_movable $eco_name(106)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(106)/A"] -location {314.284 312.068} -buffer_name {ci_eco_0107} -net_name {ci_eco_0107_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(107) [get_property $created full_name]
lappend eco_movable $eco_name(107)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(107)/A"] -location {380.810 306.380} -buffer_name {ci_eco_0108} -net_name {ci_eco_0108_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(108) [get_property $created full_name]
lappend eco_movable $eco_name(108)
replace_cell {_20878_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20878_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21941_/A1} {_22110_/A0} {_22074_/A0} {_20893_/B2}] -location {32.959 348.233} -buffer_name {ci_eco_0109} -net_name {ci_eco_0109_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(109) [get_property $created full_name]
lappend eco_movable $eco_name(109)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20948_/A1} {_21083_/B}] -location {154.925 363.986} -buffer_name {ci_eco_0110} -net_name {ci_eco_0110_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(110) [get_property $created full_name]
lappend eco_movable $eco_name(110)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21791_/A0} {_20879_/A1}] -location {91.864 328.702} -buffer_name {ci_eco_0111} -net_name {ci_eco_0111_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(111) [get_property $created full_name]
lappend eco_movable $eco_name(111)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(109)/A"] -location {74.734 341.509} -buffer_name {ci_eco_0112} -net_name {ci_eco_0112_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(112) [get_property $created full_name]
lappend eco_movable $eco_name(112)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(112)/A" "$eco_name(111)/A" "$eco_name(110)/A"] -location {116.510 334.784} -buffer_name {ci_eco_0113} -net_name {ci_eco_0113_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(113) [get_property $created full_name]
lappend eco_movable $eco_name(113)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(113)/A"] -location {188.061 322.181} -buffer_name {ci_eco_0114} -net_name {ci_eco_0114_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(114) [get_property $created full_name]
lappend eco_movable $eco_name(114)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(114)/A"] -location {259.613 309.578} -buffer_name {ci_eco_0115} -net_name {ci_eco_0115_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(115) [get_property $created full_name]
lappend eco_movable $eco_name(115)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(115)/A"] -location {331.164 296.976} -buffer_name {ci_eco_0116} -net_name {ci_eco_0116_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(116) [get_property $created full_name]
lappend eco_movable $eco_name(116)
replace_cell {_20880_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20880_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21947_/A1} {_22075_/A0} {_22111_/A0} {_20894_/B2}] -location {39.431 342.712} -buffer_name {ci_eco_0117} -net_name {ci_eco_0117_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(117) [get_property $created full_name]
lappend eco_movable $eco_name(117)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21797_/A_N} {_20881_/A1}] -location {65.082 330.618} -buffer_name {ci_eco_0118} -net_name {ci_eco_0118_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(118) [get_property $created full_name]
lappend eco_movable $eco_name(118)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {ANTENNA_113/DIODE} {ANTENNA_115/DIODE} {ANTENNA_117/DIODE} {ANTENNA_119/DIODE} {ANTENNA_121/DIODE}] -location {222.640 338.640} -buffer_name {ci_eco_0119} -net_name {ci_eco_0119_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(119) [get_property $created full_name]
lappend eco_movable $eco_name(119)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_118/DIODE} {ANTENNA_116/DIODE} {ANTENNA_114/DIODE} {_21083_/C} "$eco_name(119)/A"] -location {168.454 338.750} -buffer_name {ci_eco_0120} -net_name {ci_eco_0120_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(120) [get_property $created full_name]
lappend eco_movable $eco_name(120)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(117)/A" "$eco_name(118)/A" {_20955_/A1} {ANTENNA_122/DIODE} {ANTENNA_120/DIODE} "$eco_name(120)/A"] -location {121.397 338.832} -buffer_name {ci_eco_0121} -net_name {ci_eco_0121_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(121) [get_property $created full_name]
lappend eco_movable $eco_name(121)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(121)/A"] -location {183.217 329.911} -buffer_name {ci_eco_0122} -net_name {ci_eco_0122_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(122) [get_property $created full_name]
lappend eco_movable $eco_name(122)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(122)/A"] -location {245.037 320.989} -buffer_name {ci_eco_0123} -net_name {ci_eco_0123_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(123) [get_property $created full_name]
lappend eco_movable $eco_name(123)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(123)/A"] -location {306.856 312.068} -buffer_name {ci_eco_0124} -net_name {ci_eco_0124_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(124) [get_property $created full_name]
lappend eco_movable $eco_name(124)
replace_cell {_20882_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_20882_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21951_/A1} {_22076_/A0} {_20883_/A1} {_20895_/B2}] -location {38.686 342.793} -buffer_name {ci_eco_0125} -net_name {ci_eco_0125_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(125) [get_property $created full_name]
lappend eco_movable $eco_name(125)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21801_/A0} {_20962_/A1}] -location {74.341 342.495} -buffer_name {ci_eco_0126} -net_name {ci_eco_0126_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(126) [get_property $created full_name]
lappend eco_movable $eco_name(126)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(126)/A" {_22112_/A0} {_21083_/D}] -location {139.424 342.495} -buffer_name {ci_eco_0127} -net_name {ci_eco_0127_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(127) [get_property $created full_name]
lappend eco_movable $eco_name(127)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(125)/A" "$eco_name(127)/A"] -location {115.724 342.495} -buffer_name {ci_eco_0128} -net_name {ci_eco_0128_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(128) [get_property $created full_name]
lappend eco_movable $eco_name(128)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(128)/A"] -location {195.867 334.018} -buffer_name {ci_eco_0129} -net_name {ci_eco_0129_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(129) [get_property $created full_name]
lappend eco_movable $eco_name(129)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(129)/A"] -location {276.010 325.541} -buffer_name {ci_eco_0130} -net_name {ci_eco_0130_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(130) [get_property $created full_name]
lappend eco_movable $eco_name(130)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(130)/A"] -location {356.153 317.063} -buffer_name {ci_eco_0131} -net_name {ci_eco_0131_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(131) [get_property $created full_name]
lappend eco_movable $eco_name(131)
replace_cell {_22831_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_22831_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_21477_/D_N} {_22838_/A_N}] -location {259.881 376.567} -buffer_name {ci_eco_0132} -net_name {ci_eco_0132_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(132) [get_property $created full_name]
lappend eco_movable $eco_name(132)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(132)/A" {place6187/A} {_22157_/A1} {_14474_/A0}] -location {318.777 380.842} -buffer_name {ci_eco_0133} -net_name {ci_eco_0133_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(133) [get_property $created full_name]
lappend eco_movable $eco_name(133)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22166_/A1} {_22184_/A0} {_22148_/A1} {_24227_/A0} {_22175_/A0}] -location {418.651 404.221} -buffer_name {ci_eco_0134} -net_name {ci_eco_0134_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(134) [get_property $created full_name]
lappend eco_movable $eco_name(134)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(133)/A" "$eco_name(134)/A"] -location {353.277 386.450} -buffer_name {ci_eco_0135} -net_name {ci_eco_0135_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(135) [get_property $created full_name]
lappend eco_movable $eco_name(135)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(135)/A"] -location {408.550 363.304} -buffer_name {ci_eco_0136} -net_name {ci_eco_0136_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(136) [get_property $created full_name]
lappend eco_movable $eco_name(136)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(136)/A"] -location {463.823 340.159} -buffer_name {ci_eco_0137} -net_name {ci_eco_0137_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(137) [get_property $created full_name]
lappend eco_movable $eco_name(137)
replace_cell {_22839_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_22839_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20928_/A0}] -location {116.173 377.608} -buffer_name {ci_eco_0138} -net_name {ci_eco_0138_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(138) [get_property $created full_name]
lappend eco_movable $eco_name(138)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22841_/A}] -location {183.264 353.233} -buffer_name {ci_eco_0139} -net_name {ci_eco_0139_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(139) [get_property $created full_name]
lappend eco_movable $eco_name(139)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(138)/A" "$eco_name(139)/A"] -location {149.719 365.420} -buffer_name {ci_eco_0140} -net_name {ci_eco_0140_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(140) [get_property $created full_name]
lappend eco_movable $eco_name(140)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {place6183/A} {_22150_/A1}] -location {320.199 362.986} -buffer_name {ci_eco_0141} -net_name {ci_eco_0141_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(141) [get_property $created full_name]
lappend eco_movable $eco_name(141)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(141)/A"] -location {275.470 364.203} -buffer_name {ci_eco_0142} -net_name {ci_eco_0142_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(142) [get_property $created full_name]
lappend eco_movable $eco_name(142)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(140)/A" "$eco_name(142)/A"] -location {230.742 365.420} -buffer_name {ci_eco_0143} -net_name {ci_eco_0143_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(143) [get_property $created full_name]
lappend eco_movable $eco_name(143)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24231_/A0} {_22159_/A1} {_22177_/A0} {_22168_/A1} {_22186_/A0}] -location {363.994 394.635} -buffer_name {ci_eco_0144} -net_name {ci_eco_0144_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(144) [get_property $created full_name]
lappend eco_movable $eco_name(144)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(144)/A"] -location {310.250 387.770} -buffer_name {ci_eco_0145} -net_name {ci_eco_0145_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(145) [get_property $created full_name]
lappend eco_movable $eco_name(145)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(143)/A" "$eco_name(145)/A"] -location {256.507 380.905} -buffer_name {ci_eco_0146} -net_name {ci_eco_0146_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(146) [get_property $created full_name]
lappend eco_movable $eco_name(146)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(146)/A"] -location {314.597 353.172} -buffer_name {ci_eco_0147} -net_name {ci_eco_0147_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(147) [get_property $created full_name]
lappend eco_movable $eco_name(147)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(147)/A"] -location {372.686 325.439} -buffer_name {ci_eco_0148} -net_name {ci_eco_0148_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(148) [get_property $created full_name]
lappend eco_movable $eco_name(148)
replace_cell {_22840_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_22840_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {ANTENNA_142/DIODE} {_20935_/A0} {ANTENNA_143/DIODE}] -location {153.870 368.560} -buffer_name {ci_eco_0149} -net_name {ci_eco_0149_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(149) [get_property $created full_name]
lappend eco_movable $eco_name(149)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22160_/A1} {_22151_/A1} {_22169_/A1} {_22187_/A0} {_22178_/A0} {_24233_/A0}] -location {406.237 396.060} -buffer_name {ci_eco_0150} -net_name {ci_eco_0150_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(150) [get_property $created full_name]
lappend eco_movable $eco_name(150)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(149)/A" {_22841_/B} {ANTENNA_144/DIODE} {place6182/A}] -location {210.357 377.374} -buffer_name {ci_eco_0151} -net_name {ci_eco_0151_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(151) [get_property $created full_name]
lappend eco_movable $eco_name(151)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(150)/A"] -location {332.680 389.843} -buffer_name {ci_eco_0152} -net_name {ci_eco_0152_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(152) [get_property $created full_name]
lappend eco_movable $eco_name(152)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(151)/A" "$eco_name(152)/A"] -location {259.123 383.625} -buffer_name {ci_eco_0153} -net_name {ci_eco_0153_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(153) [get_property $created full_name]
lappend eco_movable $eco_name(153)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(153)/A"] -location {313.428 358.612} -buffer_name {ci_eco_0154} -net_name {ci_eco_0154_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(154) [get_property $created full_name]
lappend eco_movable $eco_name(154)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(154)/A"] -location {367.732 333.599} -buffer_name {ci_eco_0155} -net_name {ci_eco_0155_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(155) [get_property $created full_name]
lappend eco_movable $eco_name(155)
replace_cell {_22842_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_22842_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20956_/A0} {place6181/A}] -location {184.734 399.673} -buffer_name {ci_eco_0156} -net_name {ci_eco_0156_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(156) [get_property $created full_name]
lappend eco_movable $eco_name(156)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_22846_/A} {_24239_/A0}] -location {354.269 378.243} -buffer_name {ci_eco_0157} -net_name {ci_eco_0157_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(157) [get_property $created full_name]
lappend eco_movable $eco_name(157)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(156)/A"] -location {219.931 388.957} -buffer_name {ci_eco_0158} -net_name {ci_eco_0158_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(158) [get_property $created full_name]
lappend eco_movable $eco_name(158)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {_22154_/A1} {_22163_/A1} {_22172_/A1} {_22190_/A0} {_22181_/A0}] -location {420.721 401.500} -buffer_name {ci_eco_0159} -net_name {ci_eco_0159_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(159) [get_property $created full_name]
lappend eco_movable $eco_name(159)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(159)/A"] -location {347.239 391.231} -buffer_name {ci_eco_0160} -net_name {ci_eco_0160_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(160) [get_property $created full_name]
lappend eco_movable $eco_name(160)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(158)/A" "$eco_name(157)/A" "$eco_name(160)/A"] -location {273.757 380.962} -buffer_name {ci_eco_0161} -net_name {ci_eco_0161_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(161) [get_property $created full_name]
lappend eco_movable $eco_name(161)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(161)/A"] -location {326.007 364.975} -buffer_name {ci_eco_0162} -net_name {ci_eco_0162_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(162) [get_property $created full_name]
lappend eco_movable $eco_name(162)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(162)/A"] -location {378.256 348.988} -buffer_name {ci_eco_0163} -net_name {ci_eco_0163_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(163) [get_property $created full_name]
lappend eco_movable $eco_name(163)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(163)/A"] -location {430.506 333.000} -buffer_name {ci_eco_0164} -net_name {ci_eco_0164_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(164) [get_property $created full_name]
lappend eco_movable $eco_name(164)
replace_cell {_22845_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_22845_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_20942_/A0} {ANTENNA_315/DIODE}] -location {165.004 393.935} -buffer_name {ci_eco_0165} -net_name {ci_eco_0165_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(165) [get_property $created full_name]
lappend eco_movable $eco_name(165)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {place6176/A} {ANTENNA_145/DIODE} {_22846_/D}] -location {247.518 363.836} -buffer_name {ci_eco_0166} -net_name {ci_eco_0166_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(166) [get_property $created full_name]
lappend eco_movable $eco_name(166)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(165)/A" "$eco_name(166)/A"] -location {212.104 378.248} -buffer_name {ci_eco_0167} -net_name {ci_eco_0167_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(167) [get_property $created full_name]
lappend eco_movable $eco_name(167)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24235_/A0} {_22161_/A1} {_22152_/A1} {_22188_/A0} {_22170_/A1} {_22179_/A0}] -location {422.337 401.500} -buffer_name {ci_eco_0168} -net_name {ci_eco_0168_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(168) [get_property $created full_name]
lappend eco_movable $eco_name(168)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(168)/A"] -location {352.072 392.594} -buffer_name {ci_eco_0169} -net_name {ci_eco_0169_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(169) [get_property $created full_name]
lappend eco_movable $eco_name(169)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(167)/A" "$eco_name(169)/A"] -location {281.807 383.688} -buffer_name {ci_eco_0170} -net_name {ci_eco_0170_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(170) [get_property $created full_name]
lappend eco_movable $eco_name(170)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(170)/A"] -location {340.970 354.209} -buffer_name {ci_eco_0171} -net_name {ci_eco_0171_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(171) [get_property $created full_name]
lappend eco_movable $eco_name(171)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(171)/A"] -location {400.133 324.731} -buffer_name {ci_eco_0172} -net_name {ci_eco_0172_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(172) [get_property $created full_name]
lappend eco_movable $eco_name(172)
replace_cell {_23154_} {sky130_fd_sc_hd__a21oi_4}
estimate_parasitics -placement
lappend eco_movable {_23154_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_4} -load_pins [list {_24479_/A2} {_24437_/A1} {_24459_/B1}] -location {277.885 191.921} -buffer_name {ci_eco_0173} -net_name {ci_eco_0173_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(173) [get_property $created full_name]
lappend eco_movable $eco_name(173)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_15164_/A} {_15219_/A} {_15250_/A1} {_15170_/A} {_15195_/A1}] -location {206.610 146.208} -buffer_name {ci_eco_0174} -net_name {ci_eco_0174_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(174) [get_property $created full_name]
lappend eco_movable $eco_name(174)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(174)/A" {_15194_/A} {_19858_/A} "$eco_name(173)/A"] -location {237.386 164.646} -buffer_name {ci_eco_0175} -net_name {ci_eco_0175_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(175) [get_property $created full_name]
lappend eco_movable $eco_name(175)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(175)/A"] -location {271.932 178.505} -buffer_name {ci_eco_0176} -net_name {ci_eco_0176_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(176) [get_property $created full_name]
lappend eco_movable $eco_name(176)
replace_cell {_23560_} {sky130_fd_sc_hd__o31ai_4}
estimate_parasitics -placement
lappend eco_movable {_23560_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_23580_/A1} {_23719_/A} {_23720_/A2}] -location {425.233 80.448} -buffer_name {ci_eco_0177} -net_name {ci_eco_0177_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(177) [get_property $created full_name]
lappend eco_movable $eco_name(177)
replace_cell {_23906_} {sky130_fd_sc_hd__mux2_2}
estimate_parasitics -placement
lappend eco_movable {_23906_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_23912_/B} {place5991/A} {_23907_/B} {place5990/A} {_23909_/B}] -location {399.495 242.093} -buffer_name {ci_eco_0178} -net_name {ci_eco_0178_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(178) [get_property $created full_name]
lappend eco_movable $eco_name(178)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_14943_/B1_N} {_14838_/A1} {_14909_/S1} {_14912_/B1_N} {_14848_/C}] -location {379.743 315.607} -buffer_name {ci_eco_0179} -net_name {ci_eco_0179_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(179) [get_property $created full_name]
lappend eco_movable $eco_name(179)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(178)/A" "$eco_name(179)/A"] -location {379.743 272.080} -buffer_name {ci_eco_0180} -net_name {ci_eco_0180_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(180) [get_property $created full_name]
lappend eco_movable $eco_name(180)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(180)/A"] -location {350.750 218.387} -buffer_name {ci_eco_0181} -net_name {ci_eco_0181_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(181) [get_property $created full_name]
lappend eco_movable $eco_name(181)
replace_cell {_23975_} {sky130_fd_sc_hd__o21ai_4}
estimate_parasitics -placement
lappend eco_movable {_23975_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24053_/A2} {_24069_/A2} {_23976_/A} {_14930_/A2}] -location {325.228 266.567} -buffer_name {ci_eco_0182} -net_name {ci_eco_0182_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(182) [get_property $created full_name]
lappend eco_movable $eco_name(182)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(182)/A"] -location {306.575 219.122} -buffer_name {ci_eco_0183} -net_name {ci_eco_0183_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(183) [get_property $created full_name]
lappend eco_movable $eco_name(183)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(183)/A"] -location {287.921 171.676} -buffer_name {ci_eco_0184} -net_name {ci_eco_0184_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(184) [get_property $created full_name]
lappend eco_movable $eco_name(184)
replace_cell {_24318_} {sky130_fd_sc_hd__nor3_4}
estimate_parasitics -placement
lappend eco_movable {_24318_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_19397_/A} {place5775/A} {_19362_/B} {_17877_/B} {place5788/A} {_19299_/B} {_17872_/B} {_17922_/B}] -location {618.496 108.787} -buffer_name {ci_eco_0185} -net_name {ci_eco_0185_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(185) [get_property $created full_name]
lappend eco_movable $eco_name(185)
replace_cell {_24499_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_24499_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24858_/A2} {_24880_/A2} {place5747/A} {_24695_/A2} {place5749/A}] -location {130.442 149.501} -buffer_name {ci_eco_0186} -net_name {ci_eco_0186_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(186) [get_property $created full_name]
lappend eco_movable $eco_name(186)
replace_cell {_24516_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_24516_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24521_/A} {_24556_/B} {_24666_/A2} {_24685_/A2} {_25527_/A2}] -location {221.230 194.673} -buffer_name {ci_eco_0187} -net_name {ci_eco_0187_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(187) [get_property $created full_name]
lappend eco_movable $eco_name(187)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_19784_/A} {_24626_/B1} {_24702_/A2} {place5743/A} {_24598_/A2} "$eco_name(187)/A"] -location {185.755 194.308} -buffer_name {ci_eco_0188} -net_name {ci_eco_0188_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(188) [get_property $created full_name]
lappend eco_movable $eco_name(188)
replace_cell {_24524_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_24524_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24852_/B1} {place5679/A} {place5680/A} {_24814_/B1}] -location {93.814 171.358} -buffer_name {ci_eco_0189} -net_name {ci_eco_0189_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(189) [get_property $created full_name]
lappend eco_movable $eco_name(189)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(189)/A" {_24725_/B1} {_24711_/A2} {_24636_/B1} {_24539_/A}] -location {141.161 163.274} -buffer_name {ci_eco_0190} -net_name {ci_eco_0190_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(190) [get_property $created full_name]
lappend eco_movable $eco_name(190)
replace_cell {_24528_} {sky130_fd_sc_hd__nor2_4}
estimate_parasitics -placement
lappend eco_movable {_24528_}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24914_/A2} {place5736/A} {_24950_/B1} {place5735/A} {_24977_/A2}] -location {60.612 146.877} -buffer_name {ci_eco_0191} -net_name {ci_eco_0191_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(191) [get_property $created full_name]
lappend eco_movable $eco_name(191)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24879_/A2} {_19857_/A2} {_24627_/A2} {_24559_/B} {_24539_/B}] -location {163.030 160.480} -buffer_name {ci_eco_0192} -net_name {ci_eco_0192_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(192) [get_property $created full_name]
lappend eco_movable $eco_name(192)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(191)/A" "$eco_name(192)/A"] -location {122.550 146.877} -buffer_name {ci_eco_0193} -net_name {ci_eco_0193_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(193) [get_property $created full_name]
lappend eco_movable $eco_name(193)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(193)/A"] -location {165.260 150.447} -buffer_name {ci_eco_0194} -net_name {ci_eco_0194_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(194) [get_property $created full_name]
lappend eco_movable $eco_name(194)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__clkbuf_16} -load_pins [list {clkbuf_3_0_0_clk/A} {clkbuf_3_2_0_clk/A} {clkbuf_3_1_0_clk/A} {clkbuf_3_3_0_clk/A}] -location {381.177 266.725} -buffer_name {ci_eco_0195} -net_name {ci_eco_0195_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(195) [get_property $created full_name]
lappend eco_movable $eco_name(195)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__clkbuf_16} -load_pins [list {clkbuf_3_6_0_clk/A} {clkbuf_3_4_0_clk/A} {clkbuf_3_5_0_clk/A} {clkbuf_3_7_0_clk/A}] -location {483.211 260.690} -buffer_name {ci_eco_0196} -net_name {ci_eco_0196_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(196) [get_property $created full_name]
lappend eco_movable $eco_name(196)
replace_cell {fanout2248} {sky130_fd_sc_hd__clkdlybuf4s25_2}
estimate_parasitics -placement
lappend eco_movable {fanout2248}
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_23800_/B} {place6896/A}] -location {205.857 423.332} -buffer_name {ci_eco_0197} -net_name {ci_eco_0197_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(197) [get_property $created full_name]
lappend eco_movable $eco_name(197)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_23895_/A2}] -location {287.770 239.488} -buffer_name {ci_eco_0198} -net_name {ci_eco_0198_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(198) [get_property $created full_name]
lappend eco_movable $eco_name(198)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(198)/A"] -location {264.401 287.024} -buffer_name {ci_eco_0199} -net_name {ci_eco_0199_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(199) [get_property $created full_name]
lappend eco_movable $eco_name(199)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(197)/A"] -location {223.444 378.947} -buffer_name {ci_eco_0200} -net_name {ci_eco_0200_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(200) [get_property $created full_name]
lappend eco_movable $eco_name(200)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(199)/A" "$eco_name(200)/A"] -location {241.031 334.560} -buffer_name {ci_eco_0201} -net_name {ci_eco_0201_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(201) [get_property $created full_name]
lappend eco_movable $eco_name(201)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list {_24290_/B1} {_30304_/SET_B} {_30315_/SET_B}] -location {94.907 497.605} -buffer_name {ci_eco_0202} -net_name {ci_eco_0202_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(202) [get_property $created full_name]
lappend eco_movable $eco_name(202)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(202)/A"] -location {123.381 447.737} -buffer_name {ci_eco_0203} -net_name {ci_eco_0203_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(203) [get_property $created full_name]
lappend eco_movable $eco_name(203)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(203)/A"] -location {151.854 397.869} -buffer_name {ci_eco_0204} -net_name {ci_eco_0204_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(204) [get_property $created full_name]
lappend eco_movable $eco_name(204)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(201)/A" "$eco_name(204)/A"] -location {180.327 348.000} -buffer_name {ci_eco_0205} -net_name {ci_eco_0205_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(205) [get_property $created full_name]
lappend eco_movable $eco_name(205)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(205)/A"] -location {168.253 399.337} -buffer_name {ci_eco_0206} -net_name {ci_eco_0206_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(206) [get_property $created full_name]
lappend eco_movable $eco_name(206)
set created [insert_buffer -buffer_cell {sky130_fd_sc_hd__buf_8} -load_pins [list "$eco_name(206)/A"] -location {156.179 450.674} -buffer_name {ci_eco_0207} -net_name {ci_eco_0207_net}]
if {$created == "NULL"} {error "ECO buffer insertion failed"}
set eco_name(207) [get_property $created full_name]
lappend eco_movable $eco_name(207)
