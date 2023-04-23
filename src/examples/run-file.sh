#!/bin/sh

file="$1"

if [ ! -f "$file" ]
then
  echo "Usage: $0 <src>"
  exit 1
fi

case "$file" in
  *\.c)
    bin=$(cat "$file" | ./build.sh)
    ;;
  *\.asm)
    bin=$(cat "$file" | ../assembler/uasm)
    ;;
  *)
    bin=$(cat "$file")
    ;;
esac

./send.sh $bin
