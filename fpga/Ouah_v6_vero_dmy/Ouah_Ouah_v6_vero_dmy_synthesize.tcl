if {[catch {

# define run engine funtion
source [file join {C:/lscc/radiant/3.2} scripts tcl flow run_engine.tcl]
# define global variables
global para
set para(gui_mode) 1
set para(prj_dir) "C:/Users/duodi/Documents/Personnel/electronique/fpga-cpld/lattice/Ouah"
# synthesize IPs
# synthesize VMs
# synthesize top design
file delete -force -- Ouah_Ouah_v6_vero_dmy.vm Ouah_Ouah_v6_vero_dmy.ldc
run_engine_newmsg synthesis -f "Ouah_Ouah_v6_vero_dmy_lattice.synproj"
run_postsyn [list -a iCE40UP -p iCE40UP5K -t SG48 -sp High-Performance_1.2V -oc Industrial -top -w -o Ouah_Ouah_v6_vero_dmy_syn.udb Ouah_Ouah_v6_vero_dmy.vm] "C:/Users/duodi/Documents/Personnel/electronique/fpga-cpld/lattice/Ouah/Ouah_v6_vero_dmy/Ouah_Ouah_v6_vero_dmy.ldc"

} out]} {
   runtime_log $out
   exit 1
}
