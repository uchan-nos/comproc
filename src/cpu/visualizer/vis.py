#!/usr/bin/python3
from collections import namedtuple
import drawsvg as dw


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


def draw_alu(**args):
    g = dw.Group(id='alu', fill='none', stroke='black', **args)
    p = dw.Path()
    p.M(0, 0).L(0, 15).L(10, 20).L(0, 25).L(0, 40).L(20, 30).L(20, 10).Z()
    g.append(p)
    g.append(dw.Text('A', 10, 3, 13))
    g.append(dw.Text('B', 10, 3, 33))
    return g


def draw_stack(stack, **args):
    g = dw.Group(id='stack', **args)
    for i in range(16):
        g.append(dw.Rectangle(0, i*16, 60, 16, fill='none', stroke='black'))
        g.append(dw.Text(stack[i], 16, 60//2, i*16 + 16//2, center=True, font_family='Consolas'))
    return g


def main():

    cpu = CPU()
    with open('trace.txt') as trace_file:
        for line in trace_file:
            t = parse_trace_line(line)
            print(t.time, t.values['stack0'], cpu.stack[:2], t.values['cstack0'], cpu.cstack[:2])

            d = dw.Drawing(600, 400)
            d.append(dw.Rectangle(0, 0, d.width, d.height, fill='white'))
            d.append(dw.Text('ComProc CPU Visualizer', 12, 5, 15))
            d.append(dw.Rectangle(5, 20, d.width - 10, d.height - 25, fill='none', stroke='gray', stroke_width=1))
            d.append(draw_alu(transform=f'translate({t.time}, 50)'))
            d.append(draw_stack(cpu.stack, transform='translate(10, 30)'))
            d.save_svg(f'vis-{t.time:06}.svg')

            cpu.clk(t)
 

if __name__ == '__main__':
    main()
