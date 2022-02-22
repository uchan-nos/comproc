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

vcom_line=$(cmd.exe /C "usbipd wsl list" | grep "USB Serial Converter")

if [ $(echo "$vcom_line" | wc -l) -gt 1 ]
then
  echo Multiple serial devices: please attach by hand.
  echo $0 BUS_ID
  echo "$vcom_line"
  exit 1
fi

if [ "$vcom_line" = "" ]
then
  echo Serial device not found.
  exit 1
fi

bus_id=$(echo $vcom_line | cut -f1 -d ' ')

if $(echo "$vcom_line" | grep -qv "Not attached")
then
  echo A serial device is already attached.
  echo "$vcom_line"
  exit 0
fi

echo Attaching an auto-selected device: BUS_ID = $bus_id
attach_dev $bus_id
