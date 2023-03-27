#!/bin/sh

file="$1"

if [ ! -f "$file" ]
then
  echo "Usage: $0 <src>"
  exit 1
fi

bin=$(cat "$file" | ./build.sh)
./send.sh $bin
