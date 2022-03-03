#!/usr/bin/python3

import argparse
import serial


def hex_to_bytes(hex_list, unit, byte_order):
    return b''.join(int(c, 16).to_bytes(unit, byte_order) for c in hex_list)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--dev', default='/dev/ttyUSB0',
                   help='path to a serial device')
    p.add_argument('--unit', type=int, default=1,
                   help='the number of bytes of a hex value')
    p.add_argument('hex', nargs='+',
                   help='list of hex values to send')

    args = p.parse_args()

    bytes_to_send = hex_to_bytes(args.hex, args.unit, 'big')
    ser = serial.Serial(args.dev, 9600, timeout=3, bytesize=serial.EIGHTBITS,
                        parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE)

    ser.write(bytes_to_send)
    read_bytes = ser.read(1)

    print(' '.join('{:02x}'.format(b) for b in read_bytes))
    ser.close()


if __name__ == '__main__':
    main()
