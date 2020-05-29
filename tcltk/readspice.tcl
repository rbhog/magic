#-----------------------------------------------------------------
# readspice.tcl
#-----------------------------------------------------------------
# Defines procedure "readspice <netlist>", requiring a SPICE
# netlist as an argument.  Each .SUBCKT line in the netlist
# is used to force the port ordering in the layout of the cell
# with the same subcircuit name.
#
# NOTE:  This is NOT a schematic-to-layout function!  Its purpose
# is to annotate cells with information in a netlist.  The cell
# layout must exist before reading the corresponding netlist.
#-----------------------------------------------------------------

global Opts

proc readspice {netfile} {
   if [catch {open  $netfile r} fnet] {
      set netname [file rootname $netfile]

      # Check for standard extensions (.spi, .spc, .spice, .sp, .ckt)

      set testnetfile ${netname}.spi
      if [catch {open  ${testnetfile} r} fnet] {
         set testnetfile ${netname}.spc
         if [catch {open  ${testnetfile} r} fnet] {
            set testnetfile ${netname}.spice
            if [catch {open  ${testnetfile} r} fnet] {
               set testnetfile ${netname}.sp
               if [catch {open  ${testnetfile} r} fnet] {
                  set testnetfile ${netname}.ckt
                  if [catch {open  ${testnetfile} r} fnet] {
                     puts stderr "Error:  Can't read netlist file $netfile"
	             return 1;
		  }
	       }
	    }
	 }
      }
      set netfile $testnetfile
   }

   # Read data from file.  Remove comment lines and concatenate
   # continuation lines.

   puts stderr "Annotating port orders from $netfile"
   set fdata {}
   set lastline ""
   while {[gets $fnet line] >= 0} {
       if {[lindex $line 0] != "*"} {
           if {[lindex $line 0] == "+"} {
               if {[string range $line end end] != " "} {
                  append lastline " "
	       }
               append lastline [string range $line 1 end]
	   } else {
	       lappend fdata $lastline
               set lastline $line
	   }
       }
   }
   lappend fdata $lastline

   # Now look for all ".subckt" lines

   suspendall
   foreach line $fdata {
       set ftokens [split $line]
       set keyword [string tolower [lindex $ftokens 0]]
       if {$keyword == ".subckt"} {
	   set cell [lindex $ftokens 1]
	   set status [cellname list exists $cell]
	   if {$status != 0} {
	       load $cell
	       box values 0 0 0 0
	       set n 1
	       set changed false
	       foreach pin [lrange $ftokens 2 end] {

		  # NOTE:  Should probably check for CDL-isms, global bang
		  # characters, case insensitive matches, etc.  This routine
		  # currently expects a 1:1 match between netlist and layout.

		  # This routine will also make ports out of labels in the
		  # layout if they have not been read in or created as ports.
		  # However, if there are multiple labels with the same port
		  # name, only the one triggered by "goto" will be made into
		  # a port.

		  set pinidx [port $pin index]
                  if {$pinidx != ""} {
		      port $pin index $n
		      if {$pinidx != $n} {
			  set changed true
		      }
		      incr n
		  } else {
		      set layer [goto $pin]
		      if {$layer != ""} {
		         port make $n
			 incr n
			 set changed true
		      }
		  }
	       }
	       if {$changed} {
		   puts stdout "Cell $cell port order was modified."
	       }
	   } else {
	       puts stdout "Cell $cell in netlist has not been loaded."
	   }
       }
   }
   resumeall
}


#-----------------------------------------------------------------
