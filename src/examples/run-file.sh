#!/bin/sh

file="$1"

if [ ! -f "$file" ]
then
  echo "Usage: $0 <src>"
  exit 1
fi

base=$(basename "$file" .c)
./build.sh "$file"
./send.sh "$base.pmem.hex" "$base.dmem.hex"
