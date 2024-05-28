#!/bin/bash -u

target=${TARGET:-sim}
uart_dev="${UART_DEV:-/dev/ttyUSB0}"

echo Testing with TARGET=$target. Target list:
echo "  sim   Simulation"
echo "  uart  Using real CPU"

if [ "$target" = "uart" ] && [ ! -e $uart_dev ]
then
  echo "No UART device: $uart_dev" >&2
  exit 1
fi

make -C ../compiler
make -C ../assembler
make -C ../cpu sim.exe

function test_prog() {
  src="$1"
  uart_in="./uart_in.hex"
  echo "$2" > $uart_in

  if [ "${uart_out:-}" != "" ]
  then
    uart_out_opt_sim="+uart_out=$uart_out"
    uart_out_opt_uart="--stdout $uart_out"
  else
    uart_out_opt_sim=""
    uart_out_opt_uart=""
  fi

  bin="$(echo "$src" | ../compiler/ucc -o - - | ../assembler/uasm) 7f ff"

  case $target in
    sim)
      got=$(echo $bin | ../cpu/sim.exe +uart_in=$uart_in $uart_out_opt_sim 2>&1 1>/dev/null)
      ;;
    uart)
      got=$(echo $(../../tool/uart.py --dev "$uart_dev" --delim $bin $(cat $uart_in) --timeout 3 $uart_out_opt_uart))
      ;;
    *)
      echo "unknown target: $target" >&2
      exit 1
      ;;
  esac

  echo $got
}

function test_value() {
  want="$1"
  src="$2"
  got=$(test_prog "$src" "${3:-}")

  if [ "timeout" = "$got" ]
  then
    echo "[FAILED]: $src timed out, want '$want'"
  elif [ $((0x$want)) -eq $((0x$got)) ]
  then
    echo "[  OK  ]: $src -> '$got'"
  else
    echo "[FAILED]: $src -> '$got', want '$want'"
  fi
}

function test_stdout() {
  want="$1"
  src="$2"
  uart_out="uart_out.hex"
  rm -f $uart_out
  test_prog "$src" "${3:-}"
  got=$(cat $uart_out)
  unset uart_out

  if [ "$want" = "$got" ]
  then
    echo "[  OK  ]: $src -> '$got'"
  else
    echo "[FAILED]: $src -> '$got', want '$want'"
  fi
}

function test_timeout() {
  src="$1"
  got=$(test_prog "$src" "${2:-}")

  if [ "timeout" = "$got" ]
  then
    echo "[  OK  ]: $src timed out"
  else
    echo "[FAILED]: $src didn't time out, got '$got'"
  fi
}

test_value 1f 'int main() {return 31;}'
test_value 04 'int main() {return 5 - 3 + 2;}'
test_value 07 'int main() {return 1+2*3;}'
test_value 02 'int main() {int a=3; return 5-a;}'
test_value 0a 'int main() {int a=3; int b=5; return b*(a-1);}'
test_value 08 'int main() {int a; a = 7; return a+1;}'
test_value 0a 'int main() {int a = 1; return 5*((a=3)-1);}'
test_value 01 'int main() {return 3 < 5;}'
test_value 00 'int main() {return 1 > 2;}'
test_value 01 'int main() {int a=0; a=2<3; return a;}'
test_value 03 'int main() {if(0){return 2;} return 3;}'
test_value 02 'int main() {if(4){return 2;} return 3;}'
test_value 04 'int main() {if(0) return 2; else return 4; return 3;}'
test_value 05 'int main() {int a=1; a += 2; a++; return ++a;}'
test_value 06 'int main() {int a=3; a += 2; a++; return a++;}'
test_value 05 'int main() {int a=8; a -= 2; return --a;}'
test_value 09 'int main() {int i; int s=0; for(i=2; i<=4; ++i) s+=i; return s;}'
test_value 01 'int main() {int i = 258; return i >= 250;}'
test_value 01 'int main() {int i = 258; return i * 3 > 750;}'
test_value 01 'int main() {return (10-3) == 7;}'
test_value 01 'int main() {char c = 255; c++; return c == 0;}'
test_value 07 'int main() {int a=2; int *p=&a; int b=*p; *p+=3; return a+b;}'
test_value 01 'int main() {return (1 < 3 && 3 < 2) || (2 == 3-1);}'
test_value 01 'int main() {return 3 && 5;}'
test_value 01 'int main() {char c = 255; char *p = &c; (*p)++; return *p == 0 && c == 0;}'
test_value 63 "int main() {return 'a' + 2;}"
test_value 27 "int main() {return '\'';}"
test_value 03 "int main() {return '\n' + '\0' - '\a';}"
test_value 03 "int main() {int a = 255; int b = 1025; int c = 255; return b - 1022;}"
test_value 01 'int main() {return *("012" + 1) == 49;}'
test_value 01 'int main() {return "01234"[2] == 50;}'
test_value 33 'int main() {int i = 1; return "0123"[++i + 1];}'
test_value 05 'int main() {int i = 0; while(1){if(i == 5)break; i++;} return i;}'
test_value 06 'int main() {int i; int j; int s=0; for(i=0;i<3;i++) for(j=0;j<2;j++){s++;} return s;}'
test_value 04 'int main() {if(0){if(1){return 2;}else{return 3;}}else{if(1){return 4;} return 1;}}'
test_value 05 'int main() {int *p = 0x06; while((p[1]&1) == 0); return *p + 1;}' "04"
test_value fe 'int main() {return -2;}'
test_value 03 'int main() {if (-1 < 0) { return 3; } else { return 5; }}'
test_value 85 'int main() {return 0xaf & 0xc1 | 0xfb ^ 255;}'
test_value dc 'int main() {char c = ~043; return c;}'
test_value 37 'int main() {int i; int s=0; for(i=0;i<20;i++){if(i>10){continue;} s+=i;} return s;}'
test_value 03 'int main() {int a[2]; a[1] = 3; return a[1];}'
test_value 05 'int main() {int a[2]; a[0] = 1; *(a+1) = 4; return *a + a[a[0]];}'
test_value 0f 'int main() {int a[3]; int *p = a+1; p[0] = 5; p[1] = 3; return a[1] * a[2];}'
test_value 05 'int main() {int *p=0x06; int s=0; int c=0; while(1){while((p[1]&1)==0); c=p[0]; if(c==0xfe)break; s+=c;} return s;}' "02 03 fe"
test_value 14 'int main() {return (010 >> 1) | (002 << 3);}'
test_value fe 'int main() {return 0xefff >> 12;}'
test_value ff 'int main() {return 0x8000 >> 15;}'
# test_value 00 'int main() {return 0x8000 >> 16;}' A nonsense test case due to undefined behavior
test_value 61 'int main() {int i=0; char *s="a"; while(*s){i+=*s++;} return i;}'
test_stdout 'hello' 'int main() {int *p=0x06; char *s="hello"; while(*s){*p=*s++;while((p[1]&4)==0);} *p=4; return 0;}'
test_value 03 'int f() { return 2; } int main() { return f() + 1; }'
test_value 05 'int f(int a, int b) { return a+b; } int main() { return f(2,3); }'
test_value 08 'int fib(int n) { if(n<3){return 1;}else{return fib(n-1)+fib(n-2);} } int main() { return fib(6); }'
test_value 03 'int main() {int *p = 2; *p = 2; while (*p > 0); return 3; }'
test_timeout  'int f(int ms){int *p=2; *p=ms; while(*p>0); return 0;} int main() {f(0x7fff); return 3;}'
test_value 03 'int main() {char *p=0x80; *p=2; return *p+1; }'
test_value 04 'int main() {char *p=0x81; *p=1; return *p+3; }'
test_value 81 'int f(){return 0;} int main() {char *p=0x81; *p=3; f(); return p; }'
test_value 03 'void f(int *p){*p=2;} int main(){int i; f(&i); return i+1;}'
test_value 01 'int f(){int a=2; int b=5; return a+b;} int main(){int b=1; int a=f(); return a==7 && b==1;}'
test_value 06 'int main(){int i=3; {int i=4;} return i*2;}'
test_value 08 'int main(){int i=3; {int i=4; return i*2;}}'
test_value 04 'void isr(){*(int*)0x2f0=4;} int main(){int *p=0x2f0; *p=1; asm("push isr\n\t" "pop isr\n\t" "int"); return *p;}'
test_value 05 'int main(){ char *p="foo" "ba"; int i=0; while(p[i]){i++;} return i;}'
test_value 01 'int main(){int *t=2; int *c=4; if(*c){return 4;} *t=3; while(*t); return *c;}'
test_value 05 'void _ISR(){*(int*)0x2f0+=1;*(int*)2=0;} int main(){int*t=2;int*p=0x2f0; asm("push _ISR\n\tpop isr"); *p=3;*(int*)4=2;*t=1;while(*t); *t=1;while(*t); return *p;}'
test_value 01 'int *t=2; int main(){ *t=3; while (*t>0); return 1; }'
test_value 01 'int tim_cnt __attribute__((at(2))); int main(){ tim_cnt=3; while (tim_cnt>0); return 1; }'
test_value 01 'char large[300]; char c __attribute__((at(546))); int main(){ large[290] = 3; return c - 2; }'
test_value 04 'int buf[4096]; int main(){int i; for(i=0; i<4096; i+=256){buf[i] = i;} return buf[1024]-1020; }'
test_value 02 'int main() { int i = -1; if (i < 0) { return 2; } else { return 3; } }'
