"""Area trial for a shared 31-register RF and four-entry Sv32 TLB store."""

from pathlib import Path

word_size = 32
num_words = 40
words_per_row = 1
write_size = 32
num_rw_ports = 1
num_r_ports = 1
num_w_ports = 0

tech_name = "sky130"
route_supplies = "side"
uniquify = True
nominal_corner_only = True
check_lvsdrc = False
analytical_delay = True
use_nix = False

output_name = "sky130_rf_tlb_40x32_1rw1r"
output_path = str(Path(__file__).resolve().parents[3] /
                  "build/register-file/openram-40x32")
