# First physical cell experiment: place the eight SKY130 1.8 V transistors.
# This geometry is deliberately spread out to expose every terminal for the
# first routing/LVS pass. It is NOT yet an electrically connected bit cell.
load rf8t_devices

proc addfet {type name x y width} {
    box values ${x}um ${y}um ${x}um ${y}um
    magic::gencell sky130::sky130_fd_pr__${type}_01v8 $name \
        w $width l 0.15 guard 0 glc 0 grc 0 gtc 0 gbc 0 botc 0
}

addfet pfet PQ    3 4 0.42
addfet pfet PQB   8 4 0.42
addfet nfet NQ   13 4 0.65
addfet nfet NQB  18 4 0.65
addfet nfet WAQ  23 4 0.84
addfet nfet WAQB 28 4 0.84
addfet nfet RN   33 4 0.65
addfet nfet RQ   38 4 0.65

drc check
puts "DRC errors: [drc count]"
gds write rf8t_devices.gds
writeall force
quit -noprompt
