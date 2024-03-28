#!/bin/sh

file="$1"

if [ ! -f "$file" ]
then
  echo "Usage: $0 <src>"
  exit 1
fi

case "$file" in
  *\.c)
    asm=$(../compiler/ucc -o - "$file")
    echo "===================================== ASM ====================================="
    echo "$asm"
    bin=$(echo "$asm" | ../assembler/uasm -o - -)
    echo "===================================== BIN ====================================="
    echo $bin | fold -s -w 80
    ;;
  *\.asm)
    bin=$(../assembler/uasm -o - "$file")
    echo "===================================== BIN ====================================="
    echo $bin | fold -s -w 80
    ;;
  *)
    bin=$(cat "$file")
    ;;
esac

./send.sh $bin
