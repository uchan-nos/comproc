{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'phase',        wave: '222222222222222222', data: ['R', 'F', 'D', 'E', 'R', 'F', 'D', 'E', 'R', 'F', 'D', 'E', 'R', 'F', 'D', 'E', 'R', 'F']},
    {name: 'ip',           wave: '3.2.4.7.5.6...2.7.', data: ['X', 'X+2', 'y', 'y+2', 'z', 'z+2', 'z+4', 'y+2']},
    {name: 'load_ip',      wave: '01010101010..10101'}, // phase_fetch | reload_ip
    {name: 'src_a',        wave: '2.2.2.2.2.2.2.2.2.', data: ['ip', 'ip', 'ip', 'ip', 'ip', 'stack0', 'ip', 'cstack', 'ip']},
    {name: 'src_b',        wave: 'x.2.......2.......', data: ['imm', 'stack1']},
  	{name: 'alu_sel',      wave: '22x2222222x222x222', data: ['A', 'INC2', 'ADD', 'A', 'INC2', 'A', 'ADD', 'A', 'INC2', 'AND', 'A', 'INC2', 'A', 'A', 'INC2']},
    {name: 'alu_out',      wave: '32x4.7.5.6x262x7.8', data: ['X', 'X+2', 'y=X+2+Y', 'y+2', 'z=y+2+Z', 'z+2', 'S2', 'z+2', 'z+4', 'y+2', 'y+4']},
    {name: 'rd_data',      wave: 'x3x.4.7.5.6x.6x.7.', data: ['ins1', 'ins2', 'ins5', 'ins3', 'ins4', 'ins4', 'ins5', 'ins5']},
    {name: 'insn',         wave: 'x.3...4...5...6...', data: ['ins1: JMP Y', 'ins2: CALL Z', 'ins3: AND', 'ins4: RET']},
    {name: 'stack0',       wave: '2...........2.....', data: ['S0', 'S2=S0&S1']},
    {name: 'stack1',       wave: '2...........x.....', data: ['S1']},
    {name: 'pop',          wave: '0..........10.....'},
    {name: 'push',         wave: 'x0................'},
    {name: 'load_stk',     wave: '0..........10.....'}, // (~insn_rdmem & phase_exec) | (insn_rdmem & phase_rdmem)
    {name: 'cstack0',      wave: 'x......7........x.', data: ['y+2']},
    {name: 'cpop',         wave: '0..............10.'},
    {name: 'cpush',        wave: '0.....10..........'},
    {name: 'insn_src_a',   wave: 'x.2.......2...2...', data: ['ip', 'stack0', 'cstack']},
    {name: 'src_a_ip',     wave: '1.0.1.0.1.0.1.0.1.'}, // ~phase_half | insn_src_a === 2
  ],
}
