# Real-OpenDB fault injection, executed in a disposable process/checkpoint.
# Caller reads an ODB and installs the guard for two protected nets first.
set guard_test_net [[ord::get_db_block] findNet [lindex $rv32_antenna_guard::protected_nets 0]]
set guard_test_other [[ord::get_db_block] findNet [lindex $rv32_antenna_guard::protected_nets 1]]
set guard_test_reference [rv32_antenna_guard::snapshot]
rename ::rv32_original_repair_antennas ::rv32_test_unused_repair
rename ::rv32_original_detailed_route ::rv32_test_unused_route
set guard_test_mode noop
proc rv32_original_repair_antennas {args} {
    global guard_test_mode guard_test_net guard_test_other
    switch $guard_test_mode {
        noop {}
        missing {odb::dbWire_destroy [$guard_test_net getWire]}
        changed {
            odb::dbWire_destroy [$guard_test_net getWire]
            set wire [odb::dbWire_create $guard_test_net]
            $wire append [$guard_test_other getWire]
        }
        pins {[lindex [$guard_test_net getITerms] 0] disconnect}
        error {error "injected antenna failure"}
    }
    return 7
}
proc rv32_original_detailed_route {args} {
    global guard_test_net
    odb::dbWire_destroy [$guard_test_net getWire]
}
proc guard_test_reset_wire {} {
    global guard_test_net guard_test_reference_wire
    if {[$guard_test_net getWire] != "NULL"} {
        odb::dbWire_destroy [$guard_test_net getWire]
    }
    set wire [odb::dbWire_create $guard_test_net]
    $wire append $guard_test_reference_wire
}
proc guard_test_reject {script pattern} {
    if {![catch {uplevel 1 $script} message] || ![string match $pattern $message]} {
        error "Expected failure '$pattern', got '$message'"
    }
}
set guard_test_reference_wire [odb::dbWire_create [ord::get_db_block]]
$guard_test_reference_wire append [$guard_test_net getWire]
if {[repair_antennas] != 7} {error "Repair result was not forwarded"}
rv32_antenna_guard::verify $guard_test_reference
set guard_test_mode missing
if {[repair_antennas] != 7} {error "Repair result was not forwarded"}
rv32_antenna_guard::verify $guard_test_reference
set guard_test_mode changed
guard_test_reject {repair_antennas} {*Protected wire encoding changed:*}
guard_test_reset_wire
set guard_test_term [lindex [$guard_test_net getITerms] 0]
set guard_test_mode pins
guard_test_reject {repair_antennas} {*Antenna repair changed protected pins:*}
$guard_test_term connect $guard_test_net
rv32_antenna_guard::verify $guard_test_reference
set guard_test_mode error
guard_test_reject {repair_antennas} {*injected antenna failure*}
rv32_antenna_guard::verify $guard_test_reference
guard_test_reject {detailed_route} {*Protected net lost its wire:*}
guard_test_reset_wire
rv32_antenna_guard::verify $guard_test_reference
utl::suppress_message ODB 62
odb::dbWire_destroy $guard_test_reference_wire
utl::unsuppress_message ODB 62
puts "RV32 antenna guard: six real-OpenDB fault-injection checks passed"
