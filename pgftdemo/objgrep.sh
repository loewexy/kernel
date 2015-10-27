#!/bin/bash

if (( $# > 0 ))
then
    objdump -d -M intel pgftdemo.elf | sed -ne '/<'$1'>:/,/^$/p'
else
    printf "%b" "Error. Argument missing\n" >&2
    printf "%b" "Usage: objgrep.sh funcname\n" >&2
    exit 1
fi

