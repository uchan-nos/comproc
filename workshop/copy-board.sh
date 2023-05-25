#!/bin/sh

if [ $# -lt 3 ]
then
  echo "Usage: $0 <chap> <src dir> <dest dir>"
  exit 1
fi

chap=$1
src_prj=$2
dst_prj=$3
src_dir=$chap/board/$src_prj
dst_dir=$chap/board/$dst_prj

echo "Copying $src_dir to $dst_dir"

if [ ! -e $src_dir ]
then
  echo "No such dir: $src_dir"
  exit 1
fi

if [ -e $dst_dir ]
then
  echo "Already exist: $dst_dir"
  exit 1
fi

for f in $(cd $src_dir; git ls-files .)
do
  mkdir -p $dst_dir/$(dirname $f)
  cp $src_dir/$f $dst_dir/$f
done
