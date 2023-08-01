#!/usr/bin/python3
from collections import namedtuple
import drawsvg


# Types
Trace = namedtuple('Trace', ['time', 'values'])

class Stack:
    def __init__(self):
        self.stack = ['0000']*16

    def clk(self, pop, push, load, data_in):
        if pop == '1':
            if load == '1':
                self.stack = [data_in] + self.stack[2:] + ['0000']
            else:
                self.stack = self.stack[1:] + ['0000']
        elif push == '1':
            if load == '1':
                self.stack = [data_in] + self.stack[:-1]
            else:
                self.stack = ['0000'] + self.stack[:-1]
        else:
            if load == '1':
                self.stack[0] = data_in

    def __getitem__(self, pos):
        return self.stack[pos]

class CPU:
    def __init__(self):
        self.stack = Stack()
        self.cstack = Stack()

    def clk(self, trace):
        tv = trace.values
        self.stack.clk(tv['pop'], tv['push'], tv['load_stk'], tv['stack_in'])
        self.cstack.clk(tv['cpop'], tv['cpush'], tv['cpush'], tv['alu_out'])


def parse_trace_line(line):
    parts = line.split()
    values = {}
    for kv in parts[1:]:
        k, v = kv.split('=')
        values[k] = v
    return Trace(int(parts[0]), values)


def main():
    d = drawsvg.Drawing(600, 400)

    cpu = CPU()
    with open('../trace.txt') as trace_file:
        for line in trace_file:
            t = parse_trace_line(line)
            print(t.time, t.values['stack0'], cpu.stack[:2], t.values['cstack0'], cpu.cstack[:2])
            cpu.clk(t)


if __name__ == '__main__':
    main()
