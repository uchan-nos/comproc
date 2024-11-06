#!/bin/sh

if [ $# -eq 0 ] || [ $# -gt 2 ]
then
  echo "Usage: $0 src-to-run.c [uart-input.hex]"
  exit 1
elif [ "$1" = "--help" ]
then
  echo "Usage: $0 src-to-run.c [uart-input.hex]"
  exit 0
elif [ $# -eq 1 ]
then
  src=$1
  uart_in=""
else
  src=$1
  uart_in="+uart_in=$2"
fi

filename=$(basename $src .c)

if [ "$uart_out" != "" ]
then
  uart_out_opt="+uart_out=$uart_out"
fi

./build.sh $src

../cpu/sim.exe +pmem=$filename.pmem.hex +dmem=$filename.dmem.hex $uart_in $uart_out_opt > $filename.trace 2> $filename.simout
echo "Simulation trace:  $filename.trace"
echo "Simulation output: $(cat $filename.simout) ($filename.simout)"
