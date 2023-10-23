#!/usr/bin/python3

import argparse
import serial
from serial.tools.list_ports import comports
import sys


def hex_to_bytes(hex_list, unit, byte_order):
    return b''.join(int(c, 16).to_bytes(unit, byte_order) for c in hex_list)


def receive_stdout(filename, ser):
    num = 0
    with open(filename, 'wb') as f:
        b = ser.read(1)
        while len(b) == 1:
            num += 1
            f.write(b)
            if b == b'\x04':
                break
            b = ser.read(1)
    return num


def main():
    devs = comports()
    if devs:
        default_dev = devs[0].device
    else:
        default_dev = '/dev/ttyUSB0'

    p = argparse.ArgumentParser()
    p.add_argument('--dev', default=default_dev,
                   help='path to a serial device')
    p.add_argument('--unit', type=int, default=1,
                   help='the number of bytes of a hex value')
    p.add_argument('--timeout', type=int, default=3,
                   help='time to wait for result')
    p.add_argument('--nowait', action='store_true',
                   help='do not wait for result/stdout')
    p.add_argument('--stdout',
                   help='path to a file to hold bytes received')
    p.add_argument('--file',
                   help='read values from file instead of command arguments')
    p.add_argument('hex', nargs='*',
                   help='list of hex values to send')

    args = p.parse_args()

    if args.file is not None:
        with open(args.file) as f:
            file_data = f.read()
        hex_list = file_data.split()
    else:
        hex_list = args.hex
    if not hex_list:
        print('no data to send', file=sys.stderr)
        sys.exit(1)

    bytes_to_send = hex_to_bytes(hex_list, args.unit, 'big')
    ser = serial.Serial(args.dev, 115200, timeout=args.timeout,
                        bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                        stopbits=serial.STOPBITS_ONE)

    ser.write(bytes_to_send)
    ser.flush()
    if not args.nowait:
        if args.stdout:
            recv_len = receive_stdout(args.stdout, ser)
            print(f"{recv_len} bytes received and saved to '{args.stdout}'")
        else:
            read_bytes = ser.read(1)
            if len(read_bytes) == 0: # timeout
                print('timeout')
            else:
                print(' '.join('{:02x}'.format(b) for b in read_bytes))

    ser.close()


if __name__ == '__main__':
    main()
