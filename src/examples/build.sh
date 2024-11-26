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
exe=$base.exe
mode=${MODE:-os}

if [ ! -f "$src" ]
then
  echo "No such file: $src"
  exit 1
fi

ucc_opts=""
if [ "$mode" = "app" ]
then
  ucc_opts="--ret-from-start"
fi

../compiler/ucc $ucc_opts -o $asm $src
if [ $? -ne 0 ]
then
  echo $0: compilation failed
  exit 1
fi

../assembler/uasm --pmem $pmem_hex --dmem $dmem_hex --map $map -o $exe $asm
if [ $? -ne 0 ]
then
  echo $0: assembly failed
  exit 1
fi

echo build mode: $mode
echo src: $src
echo asm: $asm
echo pmem_hex: $pmem_hex
echo dmem_hex: $dmem_hex
echo map: $map
echo exe: $exe
