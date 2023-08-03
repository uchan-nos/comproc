#!/usr/bin/python3
from collections import namedtuple
import drawsvg as dw
import http.server
import jinja2
import os.path
import re
import subprocess
import time
from urllib.parse import urlparse, parse_qs


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


def draw_reg(name, value, **args):
    g = dw.Group(id='reg-' + name, **args)
    g.append(dw.Text(name, 16, -5, 8, text_anchor='end', dominant_baseline='middle'))
    g.append(dw.Rectangle(0, 0, 60, 16, fill='none', stroke='black'))
    g.append(dw.Text(value, 16, 60//2, 16//2, center=True, font_family='Consolas'))
    return g



def gen_text_appender(d):
    j = 0
    def append_text(s):
        nonlocal j
        d.append(dw.Text(s, 12, 5, 34 + 16*j))
        j += 1
    return append_text


def gen_frames():
    cpu = CPU()
    print(f'gen_frames: stack = {cpu.stack[0:2]}')
    with open('trace.txt') as trace_file:
        for i, line in enumerate(trace_file):
            if i >= 100:
                break

            t = parse_trace_line(line)

            d = dw.Drawing(600, 400)
            d.append(dw.Rectangle(0, 0, d.width, d.height, fill='white'))
            d.append(dw.Text('ComProc CPU Visualizer', 12, 5, 15))
            d.append(dw.Rectangle(5, 20, d.width - 10, d.height - 25, fill='none', stroke='gray', stroke_width=1))
            d.append(draw_alu(transform=f'translate(300, 50)'))
            d.append(draw_stack(cpu.stack, transform='translate(150, 50)'))
            append_text = gen_text_appender(d)
            append_text('Reset: ' + ('enable' if t.values['rst'] == '1' else 'disable'))
            append_text('Phase: ' + phase_names[t.values['phase']])
            d.append(draw_reg('fp', t.values['fp'], transform='translate(50, 200)'))
            d.append(draw_reg('ip', t.values['ip'], transform='translate(50, 220)'))
            d.append(draw_reg('insn', t.values['insn'], transform='translate(50, 240)'))
            d.save_svg(f'vis-{i}.svg')

            cpu.clk(t)

    global max_frame
    max_frame = i


jinja_env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
index_template = jinja_env.get_template('index-template.html')
vis_template = jinja_env.get_template('vis-template.html')
frame_filepath_pat = re.compile('/vis-[0-9]+.svg')
max_frame = -1
phase_names = {
    '0': 'Decode',
    '1': 'Execute',
    '2': 'RDMem',
    '3': 'Fetch',
    'x': '----'
}


def set_max_frame():
    global max_frame
    # -v: sort numerically, -r: reverse order
    p = subprocess.run('ls -vr vis-*.svg', shell=True, text=True, capture_output=True)
    if p.returncode != 0:
        return

    highest_file = p.stdout.splitlines()[0]
    m = re.match('vis-([0-9]+).svg', highest_file)
    if m and m.group(1):
        max_frame = int(m.group(1))


def render_vis_html():
    try:
        with open('vis.hex') as f:
            hex = f.read()
    except FileNotFoundError:
        hex = 'vis.hex not found'
    return vis_template.render(max_frame=max_frame, program_hex=hex)


def main():
    set_max_frame()
    svr = http.server.HTTPServer(('', 8080), HTTPHandler)
    svr.serve_forever()


class HTTPHandler(http.server.BaseHTTPRequestHandler):
    def send_html(self, html):
        bin = html.encode('utf-8')
        self.send_bin(bin, 'text/html; charset=utf-8')

    def send_file(self, path, mime_type):
        with open(path, 'rb') as f:
            bin = f.read()
        self.send_bin(bin, mime_type)

    def send_bin(self, bin, mime_type):
        self.send_response(200)
        self.send_header('Content-Type', mime_type)
        self.send_header('Content-Length', len(bin))
        self.end_headers()
        self.wfile.write(bin)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == '/' or url.path == '/index.html':
            self.send_html(index_template.render())
        elif url.path == '/vis.html':
            self.send_html(render_vis_html())
        elif frame_filepath_pat.match(url.path):
            self.send_file(url.path[1:], 'image/svg+xml')
        else:
            self.send_response(404)

    def do_POST(self):
        url = urlparse(self.path)
        content_len = int(self.headers.get('Content-Length'))
        post_body = self.rfile.read(content_len).decode('utf-8')
        post_dict = parse_qs(post_body)

        if url.path == '/vis.html':
            if 'program' not in post_dict or len(post_dict['program']) != 1:
                self.send_response(400)
                self.end_headers()
                return
            asm = post_dict['program'][0].replace('\r\n', '\n')
            p_asm = subprocess.run(['../assembler/uasm'], input=asm, text=True, capture_output=True)
            if p_asm.returncode != 0:
                print('uasm error: ', p_asm.stderr)
                self.send_response(500)
                self.end_headers()
                return
            hex = p_asm.stdout
            with open('vis.hex', 'w') as f:
                f.write(hex)
            p_sim = subprocess.run(['../cpu/sim.exe', '+trace_file=trace.txt'],
                                   input=hex, stdout=subprocess.DEVNULL, text=True)
            if p_sim.returncode != 0:
                print('sim.exe error: ', p_sim.stderr)
                self.send_response(500)
                self.end_headers()
                return

            gen_frames()
            self.send_html(render_vis_html())


if __name__ == '__main__':
    main()
