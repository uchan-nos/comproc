#!/bin/sh

file="$1"

if [ ! -f "$file" ]
then
  echo "Usage: $0 <src>"
  exit 1
fi

case "$file" in
  *\.c)
    asm=$(cat "$file" | ../compiler/ucc)
    echo "===================================== ASM ====================================="
    echo "$asm"
    bin=$(cat "$file" | ./build.sh)
    echo "===================================== BIN ====================================="
    echo $bin | fold -s -w 80
    ;;
  *\.asm)
    bin=$(cat "$file" | ../assembler/uasm)
    echo "===================================== BIN ====================================="
    echo $bin | fold -s -w 80
    ;;
  *)
    bin=$(cat "$file")
    ;;
esac

./send.sh $bin
