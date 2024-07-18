#!/bin/sh

if [ $# -ne 1 ]
then
  echo "Usage: $0 <src file>"
  exit 1
fi

src=$1
base=$(basename $src .c)
asm=$base.s
hex=$base.hex
map=$base.map

if [ ! -f "$src" ]
then
  echo "No such file: $src"
  exit 1
fi

../compiler/ucc -o $asm $src
../assembler/uasm -o $hex --map $map $asm

echo src: $src
echo asm: $asm
echo hex: $hex
echo map: $map
