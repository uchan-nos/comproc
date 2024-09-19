#!/bin/sh -ue

bin="$@"

if [ "$bin" = "" ]
then
  echo "Usage: $0 <instruction words>"
  exit 0
fi

../../tool/uart.py --program $bin
