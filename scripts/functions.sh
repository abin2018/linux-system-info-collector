#!/bin/bash
# Some functions

function bytes_unit_trans() {
    size=$1
    if ((size%1024==0)) ; then
	base=1024
    else
	base=1000
    fi
    echo "$size $base" | awk '{
        if ($1 < $2) {
            print $1
        } else if ($1 < $2**2) {
            print $1/($2)"KB"
        } else if ($1 < $2**3) {
            print $1/($2**2)"MB"
        } else if ($1 < $2**4) {
            print $1/($2**3)"GB"
        } else if ($1 < $2**5) {
            print $1/($2**4)"TB"
        } else if ($1 < $2**6) {
	    print $1/($2**5)"PB"
	} else { 
            print "Too big"    
        }
    }'
}

