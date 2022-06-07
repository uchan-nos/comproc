#!/bin/bash -eu

target=${TARGET:-sim}
uart_dev="${UART_DEV:-/dev/ttyUSB0}"

make -C ../compiler
make -C ../assembler
make -C ../cpu sim.exe

function test_value() {
  want="$1"
  src="$2"
  if [ $# -lt 3 ]
  then
    uart_in="ffff"
  else
    uart_in="$3"
  fi

  bin="$(echo "$src" | ../compiler/ucc | ../assembler/uasm) ffff"

  case $target in
    sim)
      got=$(echo $bin | ../cpu/sim.exe +uart_in=$uart_in 2>&1 1>/dev/null)
      ;;
    uart)
      got=$(echo $(sudo ../../tool/uart.py --dev "$uart_dev" --unit 2 $bin $uart_in --timeout 3))
      ;;
    *)
      echo "unknown target: $target"
      exit 1
      ;;
  esac

  if [ "$got" = "xx" ]
  then
    echo "[FAILED]: $src -> '$got', want '$want'"
  elif [ $((0x$want)) = $((0x$got)) ]
  then
    echo "[  OK  ]: $src -> '$got'"
  else
    echo "[FAILED]: $src -> '$got', want '$want'"
  fi
}

test_value 1f '{return 31;}'
test_value fe '{return 1 - 3;}'
test_value 07 '{return 1+2*3;}'
test_value 02 '{int a=3; return 5-a;}'
test_value 0a '{int a=3; int b=5; return b*(a-1);}'
test_value 08 '{int a; a = 7; return a+1;}'
test_value 0a '{int a = 1; return 5*((a=3)-1);}'
test_value 01 '{return 3 < 5;}'
test_value 00 '{return 1 > 2;}'
test_value 01 '{int a=0; a=2<3; return a;}'
test_value 03 '{if(0){return 2;} return 3;}'
test_value 02 '{if(4){return 2;} return 3;}'
test_value 04 '{if(0){return 2;}else{return 4;} return 3;}'
test_value 05 '{int a=1; a += 2; a++; return ++a;}'
test_value 06 '{int a=3; a += 2; a++; return a++;}'
test_value 05 '{int a=8; a -= 2; return --a;}'
test_value 09 '{int i; int s=0; for(i=2; i<5; ++i) {s+=i;} return s;}'
test_value 01 '{int i = 258; return i > 250;}'
test_value 01 '{int i = 258; return i * 3 > 750;}'
test_value 01 '{return (10-3) == 7;}'
test_value 01 '{char c = 255; c++; return c == 0;}'
test_value 07 '{int a=2; int *p=&a; int b=*p; *p+=3; return a+b;}'
test_value 01 '{return (1 < 3 && 3 < 2) || (2 == 3-1);}'
test_value 01 '{return 3 && 5;}'
test_value 01 '{char c = 255; char *p = &c; (*p)++; return *p == 0 && c == 0;}'
test_value 63 "{return 'a' + 2;}"
test_value 27 "{return '\'';}"
test_value 03 "{return '\n' + '\0' - '\a';}"
test_value 03 "{int a = 255; int b = 1025; int c = 255; return b - 1022;}"
test_value 01 '{return *("012" + 1) == 49;}'
test_value 01 '{return "01234"[2] == 50;}'
test_value 33 '{int i = 1; return "0123"[++i + 1];}'
test_value 05 '{int i = 0; while(1){if(i == 5){break;} i++;} return i;}'
test_value 06 '{int i; int j; int s=0; for(i=0;i<3;i++){for(j=0;j<2;j++){s++;}} return s;}'
test_value 04 '{if(0){if(1){return 2;}else{return 3;}}else{if(1){return 4;} return 1;}}'
test_value 05 '{int *p = 2; while(*p == -1){} return *p + 1;}' fe04
test_value fe '{return -2;}'
test_value 03 '{if (-1 < 0) { return 3; } else { return 5; }}'
test_value 85 '{return 0xaf & 0xc1 | 0xfb ^ 255;}'
test_value dc '{char c = ~043; return c;}'
#test_value 37 '{int i; int s=0; for(i=0;i<20;i++){if(i>10){continue;} s+=i;} return s;}'
