#!/bin/sh

if [ $# -ne 1 ]
then
  echo "Usage: $0 <src file>"
  exit 1
fi

src=$1
base=$(basename $src .c)
asm=$base.s
pmem_hex=$base.pmem.hex
dmem_hex=$base.dmem.hex
map=$base.map

if [ ! -f "$src" ]
then
  echo "No such file: $src"
  exit 1
fi

../compiler/ucc -o $asm $src
../assembler/uasm --pmem $pmem_hex --dmem $dmem_hex --map $map $asm

echo src: $src
echo asm: $asm
echo pmem_hex: $pmem_hex
echo dmem_hex: $dmem_hex
echo map: $map
