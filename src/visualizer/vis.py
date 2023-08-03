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
    g = dw.Group(id='alu', **args)
    p = dw.Path(fill='none', stroke='black')
    p.M(0, 0).L(0, 24).L(16, 32).L(0, 40).L(0, 64).L(30, 49).L(30, 15).Z()
    g.append(p)
    g.append(dw.Text('A', 12, 3, 16, dominant_baseline='middle'))
    g.append(dw.Text('B', 12, 3, 48, dominant_baseline='middle'))
    return g


def draw_mux2(**args):
    g = dw.Group(id='alu', **args)
    p = dw.Path(fill='none', stroke='black')
    p.M(0, 0).L(0, 64).L(30, 64-15).L(30, 15).Z()
    g.append(p)
    g.append(dw.Text('0', 12, 3, 16 + 16*0, dominant_baseline='middle'))
    g.append(dw.Text('1', 12, 3, 16 + 16*2, dominant_baseline='middle'))
    g.append(dw.Text('O', 12, 27, 64//2, text_anchor='end', dominant_baseline='middle'))
    return g


def draw_mux4(**args):
    g = dw.Group(id='alu', **args)
    p = dw.Path(fill='none', stroke='black')
    p.M(0, 0).L(0, 80).L(30, 65).L(30, 15).Z()
    g.append(p)
    g.append(dw.Text('0', 12, 3, 16 + 16*0, dominant_baseline='middle'))
    g.append(dw.Text('1', 12, 3, 16 + 16*1, dominant_baseline='middle'))
    g.append(dw.Text('2', 12, 3, 16 + 16*2, dominant_baseline='middle'))
    g.append(dw.Text('3', 12, 3, 16 + 16*3, dominant_baseline='middle'))
    g.append(dw.Text('O', 12, 27, 80//2, text_anchor='end', dominant_baseline='middle'))
    return g


def draw_stack(name, stack, depth, **args):
    g = dw.Group(id=name, **args)
    g.append(dw.Text(name, 16, 60//2, -5, text_anchor='middle'))
    for i in range(depth):
        g.append(dw.Rectangle(0, i*16, 60, 16, fill='none', stroke='black'))
        g.append(dw.Text(stack[i], 16, 60//2, i*16 + 16//2, center=True, font_family='Consolas'))
    return g


def draw_reg(name, value, **args):
    g = dw.Group(id='reg-' + name, **args)
    g.append(dw.Text(name, 16, 60//2, -5, text_anchor='middle'))
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

            stack_x = 150
            stack_y = 100
            fp_y = 100+16*4
            ip_y = 100+16*7
            cstk_y = 100+16*10
            src_a_x = 350
            src_a_y = 100
            src_b_y = 220
            alu_x = 450
            insn_y = 500
            d = dw.Drawing(800, 600)
            d.append(dw.Rectangle(0, 0, d.width, d.height, fill='white'))
            d.append(dw.Text('ComProc CPU Visualizer', 12, 5, 15))
            d.append(dw.Rectangle(5, 20, d.width - 10, d.height - 25, fill='none', stroke='gray', stroke_width=1))
            d.append(draw_alu(transform=f'translate({alu_x}, {src_a_y+40-16})'))
            append_text = gen_text_appender(d)
            append_text('Reset: ' + ('enable' if t.values['rst'] == '1' else 'disable'))
            append_text('Phase: ' + phase_names[t.values['phase']])
            d.append(draw_stack('stack', cpu.stack, 2, transform=f'translate({stack_x}, {stack_y})'))
            d.append(draw_reg('fp', t.values['fp'], transform=f'translate({stack_x}, {fp_y})'))
            d.append(draw_reg('ip', t.values['ip'], transform=f'translate({stack_x}, {ip_y})'))
            d.append(draw_stack('cstack', cpu.cstack, 2, transform=f'translate({stack_x}, {cstk_y})'))
            d.append(draw_reg('insn', t.values['insn'], transform=f'translate({stack_x}, {insn_y})'))
            d.append(draw_mux4(transform=f'translate({src_a_x}, {src_a_y})'))
            d.append(draw_mux2(transform=f'translate({src_a_x}, {src_b_y})'))
            d.append(draw_stack('stack', cpu.stack, 16, transform=f'translate(630, 300)'))
            d.append(draw_stack('cstack', cpu.cstack, 16, transform=f'translate(700, 300)'))

            line_args = {'fill': 'none'}
            src_a_stroke = lambda i: 'red' if t.values['src_a_sel'] == str(i) else 'black'
            d.append(dw.Path(stroke=src_a_stroke(0), **line_args).M(stack_x+60, stack_y+8)
                     .H(stack_x+80).V(src_a_y+16).H(src_a_x))
            d.append(dw.Path(stroke=src_a_stroke(1), **line_args).M(stack_x+60, fp_y+8)
                     .H(stack_x+80).V(src_a_y+32).H(src_a_x))
            d.append(dw.Path(stroke=src_a_stroke(2), **line_args).M(stack_x+60, ip_y+8)
                     .H(stack_x+90).V(src_a_y+48).H(src_a_x))
            d.append(dw.Path(stroke=src_a_stroke(3), **line_args).M(stack_x+60, cstk_y+8)
                     .H(stack_x+100).V(src_a_y+64).H(src_a_x))

            src_b_stroke = lambda i: 'red' if t.values['imm'] == str(i) else 'black'
            d.append(dw.Path(stroke=src_b_stroke(0), **line_args).M(stack_x+60, stack_y+16+8)
                     .H(stack_x+140).V(src_b_y+16).H(src_a_x))
            d.append(dw.Path(stroke=src_b_stroke(1), **line_args).M(stack_x+60, insn_y+8)
                     .H(stack_x+140).V(src_b_y+48).H(src_a_x))

            try:
                alu_sel = int(t.values['alu_sel'], 16)
            except ValueError:
                alu_sel = -1
            src_a_out_stroke = 'red' if 0 <= alu_sel <= 4 or 16 <= alu_sel else 'black'
            src_b_out_stroke = 'red' if 15 <= alu_sel else 'black'
            d.append(dw.Path(stroke=src_a_out_stroke, **line_args).M(src_a_x+30, src_a_y+40).H(alu_x))
            d.append(dw.Path(stroke=src_b_out_stroke, **line_args).M(src_a_x+30, src_b_y+32)
                     .H(src_a_x+60).V(src_a_y+40+32).H(alu_x))

            line_args['stroke'] = 'black'
            alu_sel_name = alu_sel_names.get(t.values['alu_sel'], '??')
            d.append(dw.Path(**line_args).M(alu_x+15, src_a_y+120).V(src_a_y+40-16+64-7.5))
            d.append(dw.Text(t.values['alu_sel'], 16, alu_x+15, src_a_y+120+16,
                             text_anchor='end', font_family='Consolas'))
            d.append(dw.Text(f'({alu_sel_name})', 16, alu_x+20, src_a_y+120+16))
            d.append(dw.Path(**line_args).M(alu_x+30, src_a_y+40-16+32).H(alu_x+150))
            d.append(dw.Text('alu_out=', 16, alu_x+120, src_a_y+40-16+32-5, text_anchor='end'))
            d.append(dw.Text(t.values['alu_out'], 16, alu_x+120, src_a_y+40-16+32-5, font_family='Consolas'))

            d.append(dw.Path(**line_args).M(src_a_x+15, src_b_y+80).V(src_b_y+64-7.5))
            d.append(dw.Text('imm=', 16, src_a_x+30, src_b_y+80+16, text_anchor='end'))
            d.append(dw.Text(t.values['imm'], 16, src_a_x+30, src_b_y+80+16, font_family='Consolas'))

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
alu_sel_names = {
    '00': 'A',
    '01': 'INC',
    '02': 'INC2',
    '03': 'INC3',
    '04': 'NOT',
    '0f': 'B',
    '10': 'AND',
    '11': 'OR',
    '12': 'XOR',
    '14': 'SHR',
    '15': 'SAR',
    '16': 'SHL',
    '17': 'JOIN',
    '20': 'ADD',
    '21': 'SUB',
    '22': 'MUL',
    '28': 'LT',
    '29': 'EQ',
    '2a': 'NEQ',
    '30': 'ADDZ',
    '31': 'ADDNZ',
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
