"""OpenRAM trial: a 32-word, 32-bit, full-word-write register-file SRAM.

The generated macro uses OpenRAM's SKY130 dual-port bitcell. It is separate
from our hand-designed 8T bitcell and does not yet implement its asynchronous
read timing contract. Generation is an area experiment, not a tapeout view.
"""

from pathlib import Path

word_size = 32
num_words = 32
write_size = 32
num_rw_ports = 1
num_r_ports = 1
num_w_ports = 0

tech_name = "sky130"
route_supplies = "side"
uniquify = True
nominal_corner_only = True

# First produce physical views. Run independent DRC/LVS and characterized
# timing before this macro can be considered for integration.
check_lvsdrc = False
analytical_delay = True
use_nix = False

output_name = "sky130_rf_32x32_1rw1r"
output_path = str(Path(__file__).resolve().parents[3] /
                  "build/register-file/openram-32x32")
