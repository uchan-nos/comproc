{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'phase',        wave: '222222222222222222', data: ['R', 'F', 'D', 'E', 'R', 'F', 'D', 'E', 'R', 'F', 'D', 'E', 'R', 'F', 'D', 'E', 'R', 'F']},
    {name: 'ip',           wave: '3.4...5...6...7...', data: ['X', 'X+2', 'X+4', 'X+6', 'X+8']},
    {name: 'load_ip',      wave: '010..10..10..10..1'}, // phase_fetch | reload_ip
    {name: 'src_a',        wave: '2.2.2.2.2.2.2.2.2.', data: ['ip', 'cstack', 'ip', 'stack0', 'ip', 'stack0', 'ip', 'stack0', 'ip']},
    {name: 'src_b',        wave: 'x.2...2...........', data: ['imm', 'stack1']},
  	{name: 'alu_sel',      wave: '22x222x222x222x222', data: ['A', 'INC2', 'ADD', 'A', 'INC2', 'A', 'A', 'INC2', 'A', 'A', 'INC2', 'ADD', 'A', 'INC2']},
    {name: 'alu_out',      wave: '34x245x256x267x278', data: ['X', 'X+2', 'T+Y', 'X+2', 'X+4', 'M0', 'X+4', 'X+6', 'M0', 'X+6', 'X+8', 'S2', 'X+8']},
    {name: 'rd_data',      wave: 'x34x245x256x267x.7', data: ['ins1', 'ins2', 'M0', 'ins2', 'ins3', 'S0', 'ins3', 'ins4', 'S0', 'ins4', 'ins5', 'ins5']},
    {name: 'wr_mem',       wave: '0......10.........'}, // insn_wrmem & phase_exec
    {name: 'wr_stk1',      wave: 'x.0...1.......0...'},
    {name: 'insn',         wave: 'x.3...4...5...6...', data: ['ins1: LD cstack+Y', 'ins2: STA', 'ins3: LDD', 'ins4: ADD']},
    {name: 'stack0',       wave: '2....2..2....2..2.', data: ['S0', 'M0', 'M0', 'S0', 'S2=S0+S1']},
    {name: 'stack1',       wave: '2....2..2.......x.', data: ['S1', 'S0', 'S1']},
    {name: 'pop',          wave: '0......10......10.'},
    {name: 'push',         wave: 'x0..10............'},
    {name: 'load_stk',     wave: '0...10.10...10.10.'}, // (~insn_rdmem & phase_exec) | (insn_rdmem & phase_rdmem)
    {name: 'fp',           wave: 'x.................'},
    {name: 'load_fp',      wave: '0.................'}, // phase_fetch | reload_ip
    {name: 'cstack0',      wave: '2.................', data: ['T']},
    {name: 'cpop',         wave: '0.................'},
    {name: 'cpush',        wave: '0.................'},
    {name: 'insn_src_a',   wave: 'x.2...2...........', data: ['cstack', 'stack0']},
    {name: 'src_a_ip',     wave: '1.0.1.0.1.0.1.0.1.'}, // ~phase_half | insn_src_a === 2
  ],
}
