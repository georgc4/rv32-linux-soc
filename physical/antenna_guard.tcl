# Preserve FIXED ECO paths across OpenROAD's incremental antenna repair.
# The pinned GRT updateDirtyNets destroys wires even when pins do not move.
# Save detached wires in the SAME block so opcode references remain valid.
namespace eval rv32_antenna_guard {
    variable protected_nets {}
    variable repair_pass 0
    variable route_pass 0
}

proc rv32_antenna_guard::pins {net} {
    set result {}
    foreach term [$net getITerms] {
        set inst [$term getInst]
        lappend result [list IT $term [$inst getName] \
            [[$term getMTerm] getName] [[$inst getMaster] getName] \
            [$inst getLocation] [$inst getOrient]]
    }
    foreach term [$net getBTerms] {
        set boxes {}
        foreach pin [$term getBPins] {
            foreach box [$pin getBoxes] {
                lappend boxes [list [[$box getTechLayer] getName] \
                    [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
            }
        }
        lappend result [list BT $term [$term getName] [lsort $boxes]]
    }
    return [lsort $result]
}

proc rv32_antenna_guard::encoding {wire} {
    set result {}
    for {set i 0} {$i < [$wire length]} {incr i} {
        lappend result [$wire getOpcode $i] [$wire getData $i]
    }
    return $result
}

proc rv32_antenna_guard::snapshot {} {
    variable protected_nets
    set block [ord::get_db_block]
    set records [dict create]
    foreach name $protected_nets {
        set net [$block findNet $name]
        if {$net == "NULL" || [$net getWire] == "NULL"} {
            error "Protected net has no wire before antenna repair: $name"
        }
        dict set records $name [list [pins $net] [encoding [$net getWire]]]
    }
    return $records
}

proc rv32_antenna_guard::verify {records} {
    set block [ord::get_db_block]
    dict for {name record} $records {
        set net [$block findNet $name]
        if {$net == "NULL" || [$net getWire] == "NULL"} {
            error "Protected net lost its wire: $name"
        }
        if {[pins $net] ne [lindex $record 0]} {
            error "Protected net pins changed: $name"
        }
        if {[encoding [$net getWire]] ne [lindex $record 1]} {
            error "Protected wire encoding changed: $name"
        }
    }
}

proc rv32_antenna_guard::repair {args} {
    variable repair_pass
    incr repair_pass
    set records [snapshot]
    set block [ord::get_db_block]
    set saved [dict create]
    set restored {}
    try {
        dict for {name record} $records {
            set copy [odb::dbWire_create $block]
            dict set saved $name $copy
            $copy append [[$block findNet $name] getWire]
        }
        set result [uplevel 1 [list rv32_original_repair_antennas {*}$args]]
        # Validate ALL pins before restoring any path. A new diode, moved pin,
        # removed net or changed cell on a protected net requires explicit
        # neighborhood expansion; replaying the old path would not be safe.
        dict for {name record} $records {
            set net [$block findNet $name]
            if {$net == "NULL" || [pins $net] ne [lindex $record 0]} {
                error "Antenna repair changed protected pins: $name"
            }
        }
        dict for {name copy} $saved {
            set net [$block findNet $name]
            if {[$net getWire] == "NULL"} {
                $copy attach $net
                $net setWireType FIXED
                lappend restored $name
            }
        }
        verify $records
        # Drop unattached backups before serializing the live design.
        utl::suppress_message ODB 62
        dict for {name copy} $saved {
            if {$name ni $restored} {odb::dbWire_destroy $copy}
        }
        set saved [dict create]
        utl::unsuppress_message ODB 62
        # Persist per-pass evidence and a checkpoint before the next DRT pass.
        set out $::env(STEP_DIR)/antenna-guard-$repair_pass
        set stream [open "$out.json" w]
        puts $stream [format {{"pass":%d,"protected_nets":%d,"restored_wires":%d,"status":"pass"}} \
            $repair_pass [dict size $records] [llength $restored]]
        close $stream
        set stream [open "$out-restored.txt" w]
        foreach name $restored {puts $stream $name}
        close $stream
        write_db "$out.odb"
        puts "RV32 antenna guard pass $repair_pass: restored [llength $restored] protected wires; verified [dict size $records] paths"
        return $result
    } finally {
        # Detached copies intentionally have no net. OpenDB warns ODB-0062 on
        # their destruction; no routing or signoff diagnostic is suppressed.
        utl::suppress_message ODB 62
        dict for {name copy} $saved {
            if {$name ni $restored} {odb::dbWire_destroy $copy}
        }
        utl::unsuppress_message ODB 62
    }
}

proc rv32_antenna_guard::route {args} {
    variable route_pass
    incr route_pass
    set records [snapshot]
    set result [uplevel 1 [list rv32_original_detailed_route {*}$args]]
    verify $records
    puts "RV32 route guard pass $route_pass: verified [dict size $records] protected paths"
    return $result
}

proc rv32_antenna_guard::install {names} {
    variable protected_nets
    set protected_nets $names
    if {[llength [info commands ::rv32_original_repair_antennas]]} {
        error "RV32 antenna guard already installed"
    }
    rename ::repair_antennas ::rv32_original_repair_antennas
    interp alias {} ::repair_antennas {} ::rv32_antenna_guard::repair
    rename ::detailed_route ::rv32_original_detailed_route
    interp alias {} ::detailed_route {} ::rv32_antenna_guard::route
}
