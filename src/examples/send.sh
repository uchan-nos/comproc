#!/bin/sh -uex

bin="$@"

if [ "$bin" = "" ]
then
  echo "Usage: $0 <instruction words (exclude last FFFF)>"
  exit 0
fi

../../tool/uart.py --unit 2 $bin ffff
