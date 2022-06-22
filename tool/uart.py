#!/usr/bin/python3

import argparse
import serial


def hex_to_bytes(hex_list, unit, byte_order):
    return b''.join(int(c, 16).to_bytes(unit, byte_order) for c in hex_list)


def receive_stdout(filename, ser):
    num = 0
    with open(filename, 'wb') as f:
        b = ser.read(1)
        while b != b'\x04':
            num += 1
            f.write(b)
            b = ser.read(1)
            if len(b) < 1:
                break
    return num


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--dev', default='/dev/ttyUSB0',
                   help='path to a serial device')
    p.add_argument('--unit', type=int, default=1,
                   help='the number of bytes of a hex value')
    p.add_argument('--timeout', type=int, default=3,
                   help='time to wait for result')
    p.add_argument('--nowait', action='store_true',
                   help='do not wait for result/stdout')
    p.add_argument('--stdout',
                   help='path to a file to hold bytes received')
    p.add_argument('hex', nargs='+',
                   help='list of hex values to send')

    args = p.parse_args()

    bytes_to_send = hex_to_bytes(args.hex, args.unit, 'big')
    ser = serial.Serial(args.dev, 9600, timeout=args.timeout,
                        bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                        stopbits=serial.STOPBITS_ONE)

    ser.write(bytes_to_send)
    ser.flush()
    if not args.nowait:
        if args.stdout:
            receive_stdout(args.stdout, ser)
        read_bytes = ser.read(1)
        print(' '.join('{:02x}'.format(b) for b in read_bytes))

    ser.close()


if __name__ == '__main__':
    main()
