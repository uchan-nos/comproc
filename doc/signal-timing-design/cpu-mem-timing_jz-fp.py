{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'phase',        wave: '222222222222222222', data: [2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]},
    {name: 'ip',           wave: '3.4...2.5.6...7...', data: ['X', 'X+2', 'X+4', 'X+8', 'X+10', 'X+12']},
    {name: 'load_ip',      wave: '01010101010..10..1'},
    {name: 'src_a',        wave: '2.2.2.2.2.2.2.2.2.', data: ['ip', 'ip', 'ip', 'ip', 'ip', 'fp', 'ip', 'cstack', 'ip']},
    {name: 'src_b',        wave: 'x.2.......2.......', data: ['imm', 'stack1']},
  	{name: 'alu_sel',      wave: '22x222x2222.22x222', data: ['A', 'A+2', 'ADDZ', 'A', 'A+2', 'ADDZ', 'A', 'A+2', 'A',   'A', 'A+2', 'A', 'A', 'A+2']},
    {name: 'alu_out',      wave: '34x4.2x5.62.67x272', data: ['X', 'X+2', 'X+2', 'X+4', 'X+8', 'X+10', 'S', 'X+10', 'X+12', 'S', 'X+12', 'X+14']},
    {name: 'rd_data',      wave: 'x34x4.x.5.6x.67x.7', data: ['ins1', 'ins2', 'ins2', 'ins3', 'ins4', 'ins4', 'ins5', 'ins5']},
    {name: 'insn',         wave: 'x.3...4...5...6...', data: ['ins1: JZ 6', 'ins2: JZ 4', 'ins3: CPUSH FP', 'ins4: CPOP FP']},
    {name: 'stack0',       wave: '2...2...x.........', data: ['1', '0']},
    {name: 'stack1',       wave: '2...x.............', data: ['0']},
    {name: 'pop',          wave: '0..10..10.........'},
    {name: 'push',         wave: 'x0................'},
    {name: 'load_stk',     wave: '0.................'},
    {name: 'fp',           wave: '2...............2.', data: ['S', 'S']},
    {name: 'load_fp',      wave: '0..............10.'},
    {name: 'cstack0',      wave: 'x..........2....x.', data: ['S']},
    {name: 'cpop',         wave: '0..............10.'},
    {name: 'cpush',        wave: '0.........10......'},
    {name: 'insn_src_a',   wave: 'x.2.......2...2...', data: ['ip', 'fp', 'cstack']},
    {name: 'src_a_ip',     wave: '1.........0.1.0.1.'},
  ],
}
