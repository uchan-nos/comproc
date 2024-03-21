#!/bin/sh

if [ $# -ne 1 ]
then
  echo "Usage: $0 <ipl source file>"
  exit 1
fi

ipl_src=$1

tool_dir=$(dirname $0)
src_dir=$tool_dir/../src
ucc=$src_dir/compiler/ucc
uasm=$src_dir/assembler/uasm

$ucc -o - $ipl_src | $uasm -o $src_dir/cpu/ipl --separate-output
