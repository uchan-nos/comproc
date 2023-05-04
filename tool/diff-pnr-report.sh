#!/bin/sh

if [ $# -eq 0 ]
then
  echo "Usage: $0 <Base Commit> [<Target Commit>]"
  exit 1
elif [ $# -eq 1 ]
then
  target="HEAD"
else
  target="$2"
fi

base="$1"

board="rev4_tangnano9k"
target_id=$(git rev-parse $target)
base_id=$(git rev-parse $base)
rptdir="$(dirname $0)/../doc/pnr-report/$board"

diff -u $rptdir/$base_id.txt $rptdir/$target_id.txt
