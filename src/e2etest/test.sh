#!/bin/bash -eu

target=${TARGET:-sim}
uart_dev="${UART_DEV:-/dev/ttyUSB0}"

make -C ../compiler
make -C ../assembler
make -C ../cpu sim.exe

function test_value() {
  want="$1"
  input="$2"

  bin="$(echo $input | ../compiler/ucc | ../assembler/uasm) ffff"

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

test_value 1f "{return 31;}"
test_value fe "{return 1 - 3;}"
test_value 07 "{return 1+2*3;}"
test_value 02 "{int a=3; return 5-a;}"
test_value 0a "{int a=3; int b=5; return b*(a-1);}"
test_value 08 "{int a; a = 7; return a+1;}"
test_value 0a "{int a = 1; return 5*((a=3)-1);}"
test_value 01 "{return 3 < 5;}"
test_value 00 "{return 1 > 2;}"
test_value 01 "{int a=0; a=2<3; return a;}"
test_value 03 "{if(0){return 2;} return 3;}"
test_value 02 "{if(4){return 2;} return 3;}"
test_value 04 "{if(0){return 2;}else{return 4;} return 3;}"
