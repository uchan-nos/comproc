#!/bin/bash -eu

target=${TARGET:-sim}
uart_dev="/dev/ttyUSB0"

function test_value() {
  want="$1"
  input="$2"

  case $target in
    sim)
      got=$(echo $input | ./sim.exe 2>&1 1>/dev/null)
      ;;
    uart)
      got=$(echo $(sudo ../../../tool/uart.py --dev "$uart_dev" --unit 2 $input))
      ;;
    *)
      echo "unknown target: $target"
      exit 1
      ;;
  esac

  if [ $((0x$want)) = $((0x$got)) ]
  then
    echo "[  OK  ]: $input -> '$got'"
  else
    echo "[FAILED]: $input -> '$got', want '$want'"
  fi
}

test_value 1f "a11f 9601 ffff"
test_value fe "a103 a101 2203 9601 ffff"
test_value 07 "a101 a102 a103 2204 2202 9601 ffff"
