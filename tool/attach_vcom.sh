#!/bin/sh

attach_dev() {
  powershell.exe Start-Process cmd.exe -Verb runas -ArgumentList cmd.exe,/C,usbipd,wsl,attach,--busid,$1
}

if [ $# -eq 1 ]
then
  echo Attaching a specified device: BUS_ID = $1
  attach_dev $1
  exit 0
fi

vcom_line=$(cd /mnt/c; cmd.exe /C usbipd wsl list | grep "USB Serial Converter")

if [ "$vcom_line" = "" ]
then
  echo Serial device not found.
  exit 0
else
  echo Showing serial devices:
  echo "$vcom_line"
  echo "To attach a device: '$0 BUS_ID'"
  exit 0
fi
