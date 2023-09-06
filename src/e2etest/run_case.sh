#!/bin/sh

bin=$(cat - | ./build.sh)
echo $bin 7fff | ../cpu/sim.exe
