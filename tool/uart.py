#!/usr/bin/python3

import argparse
import os.path
import serial
from serial.tools.list_ports import comports
import sys
import time


def hex_to_bytes(hex_list):
    return b''.join(int(c, 16).to_bytes(1, 'big') for c in hex_list)


def receive_stdout(filename, ser):
    num = 0
    with open(filename, 'wb') as f:
        b = ser.read(1)
        while b != b'\x04':
            num += 1
            f.write(b)
            b = ser.read(1)
    return (num, b)


def main():
    devs = comports()
    if devs:
        default_dev = devs[0].device
    else:
        default_dev = '/dev/ttyUSB0'

    p = argparse.ArgumentParser()
    p.add_argument('--dev', default=default_dev,
                   help='path to a serial device')
    p.add_argument('--timeout', type=int, default=3,
                   help='time to wait for result')
    p.add_argument('--nowait', action='store_true',
                   help='do not wait for result/stdout')
    p.add_argument('--stdout',
                   help='path to a file to hold bytes received')
    p.add_argument('--file',
                   help='read values from file instead of command arguments')
    p.add_argument('--delim', action='store_true',
                   help='send delimiter "55 AA" before sending data')
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

    if args.dev[0] == '/' and not os.path.exists(args.dev):
        print('No such device: ' + args.dev, file=sys.stderr)
        print("You may need 'sudo modprobe ftdi_sio'")
        sys.exit(1)

    bytes_to_send = hex_to_bytes(hex_list)
    ser = serial.Serial(args.dev, 115200, timeout=args.timeout,
                        bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                        stopbits=serial.STOPBITS_ONE)

    if args.delim:
        ser.write(b'\x55')
        ser.flush()
        time.sleep(0.005)
        ser.write(b'\xAA')
        ser.flush()

    ser.write(bytes_to_send)
    ser.flush()
    if not args.nowait:
        if args.stdout:
            recv_len, last_byte = receive_stdout(args.stdout, ser)
            info = 'with EOT' if last_byte == b'\x04' else 'no EOT'
            print(f"{recv_len} bytes ({info}) received and saved to '{args.stdout}'")
        else:
            read_bytes = ser.read(1)
            if len(read_bytes) == 0: # timeout
                print('timeout')
            else:
                print(' '.join('{:02x}'.format(b) for b in read_bytes))

    ser.close()


if __name__ == '__main__':
    main()
