#!/bin/sh

bin=$(cat - | ./build.sh)
echo $bin ffff | ../cpu/sim.exe
