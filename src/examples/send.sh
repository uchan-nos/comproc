#!/bin/sh -ue

bin="$@"

if [ "$bin" = "" ]
then
  echo "Usage: $0 <instruction words (exclude last FFFF)>"
  exit 0
fi

../../tool/uart.py --delim $bin 7f ff
