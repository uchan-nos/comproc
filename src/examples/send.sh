#!/bin/sh -ue

if [ $# -ne 2 ]
then
  echo "Usage: $0 <pmem file> <dmem file>"
  exit 1
fi

../../tool/uart.py --pmem "$1" --dmem "$2" ${UART_OPTS:-}
