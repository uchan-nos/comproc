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


cpu = CPU()
max_frame = -1


def gen_frames():
    global cpu
    global max_frame
    #cpu = CPU()
    print(f'gen_frames: stack = {cpu.stack[0:2]}')
    with open('trace.txt') as trace_file:
        for i, line in enumerate(trace_file):
            t = parse_trace_line(line)

            d = dw.Drawing(600, 400)
            d.append(dw.Rectangle(0, 0, d.width, d.height, fill='white'))
            d.append(dw.Text('ComProc CPU Visualizer', 12, 5, 15))
            d.append(dw.Rectangle(5, 20, d.width - 10, d.height - 25, fill='none', stroke='gray', stroke_width=1))
            d.append(draw_alu(transform=f'translate({t.time}, 50)'))
            d.append(draw_stack(cpu.stack, transform='translate(10, 30)'))
            d.save_svg(f'vis-{i}.svg')

            cpu.clk(t)
    max_frame = i


jinja_env = jinja2.Environment(loader=jinja2.FileSystemLoader('.'))
index_template = jinja_env.get_template('index-template.html')
vis_template = jinja_env.get_template('vis-template.html')
frame_filepath_pat = re.compile('/vis-[0-9]+.svg')


def main():
    svr = http.server.HTTPServer(('', 8080), HTTPHandler)
    svr.serve_forever()

def foobar():
    program = '''\
push 10
push 1
add
st 0x82
'''
    print('program = ' + program)
    p_asm = subprocess.run(['../assembler/uasm'], input=program, text=True, capture_output=True)
    print('returncode = ' + str(p_asm.returncode))
    program_hex = p_asm.stdout
    print('program_hex = ' + program_hex)


class HTTPHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path == '/' or url.path == '/index.html':
            index_src = index_template.render()
            index_bytes = index_src.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(index_bytes))
            self.end_headers()
            self.wfile.write(index_bytes)
        if url.path == '/vis.html':
            vis_src = vis_template.render(max_frame=max_frame)
            vis_bytes = vis_src.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(vis_bytes))
            self.end_headers()
            self.wfile.write(vis_bytes)
        elif frame_filepath_pat.match(url.path):
            start = time.time()
            with open(url.path[1:], 'rb') as f:
                img_dat = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'image/svg+xml')
            self.send_header('Content-Length', len(img_dat))
            self.end_headers()
            self.wfile.write(img_dat)
            end = time.time()
            print(f'elapsed: {end - start} secs')
        else:
            self.send_response(404)

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == '/vis.html':
            content_len = int(self.headers.get('Content-Length'))
            post_body = self.rfile.read(content_len).decode('utf-8')
            post_dict = parse_qs(post_body)
            if 'program' not in post_dict or len(post_dict['program']) != 1:
                print('bad request')
                self.send_response(400)
                self.end_headers()
                return
            program = post_dict['program'][0].replace('\r\n', '\n')
            print('program = ' + repr(program))
            p_asm = subprocess.run(['../assembler/uasm'], input=program, text=True, capture_output=True)
            print('returncode = ' + str(p_asm.returncode))
            program_hex = p_asm.stdout
            print('program_hex = ' + program_hex)
            p_sim = subprocess.run(['../cpu/sim.exe', '+trace_file=trace.txt'], input=program_hex, stdout=subprocess.DEVNULL, text=True)
            if p_sim.returncode != 0:
                print('simulator failed')
                self.send_response(500)
                self.end_headers()
                return

            global cpu
            cpu = CPU()
            gen_frames()

            vis_src = vis_template.render(max_frame=max_frame, program_hex=program_hex)
            vis_bytes = vis_src.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(vis_bytes))
            self.end_headers()
            self.wfile.write(vis_bytes)


if __name__ == '__main__':
    main()
