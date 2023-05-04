#!/bin/sh

board="rev4_tangnano9k"
commit=$(git rev-parse HEAD)
src="$(dirname $0)/../src/cpu/board/$board/impl/pnr/tangnano9k.rpt.txt"
dst="$(dirname $0)/../doc/pnr-report/$board/${commit}.txt"

force=0
if [ "$1" = "-f" ]
then
  force=1
fi

if [ $force -eq 0 ] && [ $(git diff | wc -l) -ne 0 ]
then
  echo "There are not-comitted changes (-f skip this check)"
  exit 1
fi

if [ ! -f $src ]
then
  echo No report file: $src
  exit 1
fi

if [ -f $dst ]
then
  echo Already exist: $dst
  exit 1
fi

mkdir -p $(dirname $dst)
cp $src $dst

echo Saved: $dst
cat $dst | grep -A 25 "^3. Resource Usage Summary"
echo ...snip...
