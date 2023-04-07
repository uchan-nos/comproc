{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'phase',        wave: '222222222222222222', data: [2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]},
    {name: 'ip',           wave: '3.4...5...6...7...', data: ['X', 'X+2', 'X+4', 'X+6', 'X+8']},
    {name: 'load_ip',      wave: '010..10..10..10..1'}, // phase_fetch | reload_ip
    {name: 'Source A',     wave: '2.2.2.2.2.2.2.2.2.', data: ['ip', 'stack[0]', 'ip', 'stack[0]', 'ip', 'stack[0]', 'ip', 'stack[0]', 'ip']},
    {name: 'Source B',     wave: 'x.2...2...........', data: ['imm', 'stack[1]']},
  	{name: 'ALU',          wave: '22x222x222x222x222', data: ['A', 'A+2', 'B', 'A', 'A+2', 'B', 'A', 'A+2', 'A', 'A', 'A+2', 'A+B', 'A', 'A+2']},
    {name: 'alu_out',      wave: '34x245x256x267x278', data: ['X', 'X+2', 'Y', 'X+2', 'X+4', 'S0', 'X+4', 'X+6', 'S0', 'X+6', 'X+8', 'S2', 'X+8']},
    {name: 'mem_out',      wave: 'x34x245x256x267x.7', data: ['ins1', 'ins2', 'Yr', 'ins2', 'ins3', 'Yr', 'ins3', 'ins4', 'Yr', 'ins4', 'ins5', 'ins5']},
    {name: 'wr_mem',       wave: '0......10.........'}, // insn_wrmem & phase_exec
    {name: 'insn',         wave: 'x.3...4...5...6...', data: ['ins1: LD Y', 'ins2: STA', 'ins3: LDD', 'ins4: ADD']},
    {name: 'insn_pop',     wave: 'x.0...1.......0...'},
    {name: 'insn_push',    wave: 'x.1...0...1.......'},
    {name: 'load_stack',   wave: '0...10.10...10.10.'}, // (~insn_rdmem & phase_exec) | (insn_rdmem & phase_rdmem)
    {name: 'stack[0]',     wave: '2....2..2....2..2.', data: ['S0', 'Yr', 'S0', 'Yr', 'S2=Yr+S1']},
    {name: 'stack[1]',     wave: '2....2..2.......x.', data: ['S1', 'S0', 'S1']},
    {name: 'stack[2]',     wave: 'x....2..x.......x.', data: ['S1']},
    {name: 'phase_decode', wave: '0.10..10..10..10..'}, // phase == 0
    {name: 'phase_exec',   wave: '0..10..10..10..10.'}, // phase == 1
    {name: 'phase_rdmem',  wave: '10..10..10..10..10'}, // phase == 2
    {name: 'phase_fetch',  wave: '010..10..10..10..1'}, // phase == 2
    {name: 'insn_rdmem',   wave: 'x.1...0...1...0...'},
    {name: 'insn_wrmem',   wave: 'x.0...1...0.......'},
    {name: 'insn_alu',     wave: 'x.2...2...2...2...', data: ['B', 'B', 'A', 'A+B']},
    {name: 'phase_half',   wave: '0.1.0.1.0.1.0.1.0.'}, // phase_decode | phase_exec
    {name: 'sel_a_ip',     wave: '1.0.1.0.1.0.1.0.1.'}, // ~phase_half | push_cstack
    {name: 'sel_a_stack0', wave: '0.........1.0.1.0.'}, // insn_push & phase_half
    {name: 'sel_a_ip',     wave: '1.0.1.0.1.0.1.0.1.'}, // insn_ip | ~phase_half
    {name: 'sel_a_stack0', wave: '0.1.0.1.0.1.0.1.0.'}, // sel_a_ip, sel_a_fp, sel_a_cstack がいずれも 0 のとき
  ],
}
