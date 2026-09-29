# Small, disjoint groups formed from actual synthesized signal connectivity.
# Read after read_current_odb and before global_placement, in the same process.
set locality_profile $::env(LOCALITY_PROFILE)
if {$locality_profile ni {timer_csr operands cache combined}} {
    error "Unknown locality profile: $locality_profile"
}
set locality_seen [dict create]
set locality_count 0
set locality_cells 0
set locality_report [open "$::env(STEP_DIR)/placement-clusters.tsv" w]
puts $locality_report "net\tinstances"
foreach net [lsort -command {apply {{a b} {string compare [$a getName] [$b getName]}}} [$::block getNets]] {
    # OpenDB retains backslashes in synthesized bus names.
    set name [string map {\\ ""} [$net getName]]
    set family ""
    if {[regexp {^soc\.cpu\.priv_unit\.time_value\[[0-9]+\]$} $name]} {set family timer_csr}
    if {[regexp {^soc\.cpu\.(a|b|operand_a|operand_b)\[[0-9]+\]$} $name]} {set family operands}
    if {[regexp {^soc\.memory\.(cache_line_shift|cache_data|read_shift)\[[0-9]+\]$} $name]} {set family cache}
    if {$family eq "" || ($locality_profile ne "combined" && $family ne $locality_profile)} {continue}
    set members [dict create]
    foreach iterm [$net getITerms] {
        set inst [$iterm getInst]
        set iname [$inst getName]
        if {[$inst isFixed] || [dict exists $locality_seen $iname]} {continue}
        set master [[$inst getMaster] getName]
        if {[regexp {__(diode|tap|fill|decap)} $master]} {continue}
        dict set members $iname 1
    }
    # Cap groups rather than force a whole bus or broadcast network together.
    set names [lsort [dict keys $members]]
    if {[llength $names] < 2 || [llength $names] > 24} {continue}
    placement_cluster $names
    foreach iname $names {dict set locality_seen $iname 1}
    incr locality_count
    incr locality_cells [llength $names]
    puts $locality_report "$name\t[join $names ,]"
}
close $locality_report
puts "LOCALITY profile=$locality_profile clusters=$locality_count instances=$locality_cells"
if {$locality_count == 0} {error "No placement clusters matched; refusing silent no-op experiment"}
