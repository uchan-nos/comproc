{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'phase',        wave: '222222222222222222', data: [2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]},
    {name: 'ip',           wave: '3.4...2.5.6...7...', data: ['X', 'X+2', 'X+4', 'Y', 'Y+2', 'Y+4']},
    {name: 'load_ip',      wave: '01010101010..10..1'}, // phase_fetch | reload_ip
    {name: 'Source A',     wave: '2.2.2.2.2.2.2.2.2.', data: ['ip', 'ip', 'ip', 'ip', 'ip', 'fp', 'ip', 'cstack[0]', 'ip']},
    {name: 'Source B',     wave: 'x.2...............', data: ['imm']},
  	{name: 'ALU',          wave: '22x222x222x222x222', data: ['A', 'A+2', 'A:B', 'A', 'A+2', 'A:B', 'A', 'A+2', 'A',   'A', 'A+2', 'A', 'A', 'A+2']},
    {name: 'alu_out',      wave: '34x4.2x5.6x267x272', data: ['X', 'X+2', 'X+2', 'X+4', 'Y', 'Y+2', 'S0', 'Y+2', 'Y+4', 'S0', 'Y+4', 'Y+6']},
    {name: 'mem_out',      wave: 'x34x4.x.5.6x.67x.7', data: ['ins1', 'ins2', 'ins2', 'ins3', 'ins4', 'ins4', 'ins5', 'ins5']},
    {name: 'insn',         wave: 'x.3...4...5...6...', data: ['ins1: JZ Y', 'ins2: JZ Y', 'ins3: PUSHFP', 'ins4: POPFP']},
    {name: 'insn_ip',      wave: 'x.1.......0.......',}, // ip を用いる命令
    {name: 'insn_fp',      wave: 'x.0.......1.......',}, // fp を用いる命令
    {name: 'stack[0]',     wave: '2....2....x.......', data: ['1', '0']},
    {name: 'stack[1]',     wave: '2....x............', data: ['0']},
    {name: 'insn_cpop',    wave: 'x.0...........1...'},
    {name: 'insn_cpush',   wave: 'x.0.......1...0...'},
    {name: 'fp',           wave: '2...............2.', data: ['S0', 'S0']},
    {name: 'cstack[0]',    wave: 'x...........2...x.', data: ['S0']},
    {name: 'phase_decode', wave: '0.10..10..10..10..'}, // phase == 0
    {name: 'phase_exec',   wave: '0..10..10..10..10.'}, // phase == 1
    {name: 'phase_rdmem',  wave: '10..10..10..10..10'}, // phase == 2
    {name: 'phase_fetch',  wave: '010..10..10..10..1'}, // phase == 2
    {name: 'reload_ip',    wave: '0..10..10.........'}, // insn_br & phase_exec
    {name: 'phase_half',   wave: '0.1.0.1.0.1.0.1.0.'}, // phase_decode | phase_exec
    {name: 'sel_a_ip',     wave: '1.........0.1.0.1.'}, // insn_ip | ~phase_half
    {name: 'sel_a_fp',     wave: '0.........1.0.....'}, // insn_cpush & insn_fp & phase_half
    {name: 'sel_a_cstack', wave: '0.............1.0.'}, // insn_cpop & phase_half
  ],
}
