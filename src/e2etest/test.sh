#!/bin/bash -eu

target=${TARGET:-sim}
uart_dev="/dev/ttyUSB0"

make -C ../compiler
make -C ../cpu sim.exe

function test_value() {
  want="$1"
  input="$2"

  bin="$(echo $input | ../compiler/ucc) ffff"

  case $target in
    sim)
      got=$(echo $bin | ../cpu/sim.exe 2>&1 1>/dev/null)
      ;;
    uart)
      got=$(echo $(sudo ../../tool/uart.py --dev "$uart_dev" --unit 2 $bin))
      ;;
    *)
      echo "unknown target: $target"
      exit 1
      ;;
  esac

  if [ "$got" = "xx" ]
  then
    echo "[FAILED]: $input -> '$got', want '$want'"
  elif [ $((0x$want)) = $((0x$got)) ]
  then
    echo "[  OK  ]: $input -> '$got'"
  else
    echo "[FAILED]: $input -> '$got', want '$want'"
  fi
}

test_value 1f "return 31;"
test_value fe "return 1 - 3;"
test_value 07 "return 1+2*3;"
test_value 02 "int a=3; return 5-a;"
