#!/bin/sh

if [ $# -ne 1 ]
then
  echo "Usage: $0 <ipl source file>"
  exit 1
fi

ipl_src=$1
src_base=$(basename $ipl_src .c)

tool_dir=$(dirname $0)
src_dir=$(realpath $tool_dir/../src --relative-to=.)
ucc=$src_dir/compiler/ucc
uasm=$src_dir/assembler/uasm

$ucc -o - $ipl_src | $uasm --pmem $src_dir/cpu/ipl.pmem.hex --dmem $src_dir/cpu/ipl.dmem.hex
cat $src_dir/cpu/ipl.dmem.hex | $tool_dir/separate-dmemhex.py $src_dir/cpu/ipl.dmem

echo generated following files:
ls -1 $src_dir/cpu/ipl*
