#!/bin/sh -eu

for f in $(ls tests/*.c)
do
  input="$f"
  expect="tests/$(basename $f .c).asm"
  got="$input.got.asm"
  cat "$input" | ./ucc > "$got"
  if diff -ub "$got" "$expect"
  then
    echo "[  OK  ]: '$input' is compiled expectedly."
  else
    echo "[FAILED]: got '$got', expect '$expect'"
  fi
done
