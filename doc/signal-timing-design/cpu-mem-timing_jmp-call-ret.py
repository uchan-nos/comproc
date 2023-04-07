{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'phase',        wave: '222222222222222222', data: [2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]},
    {name: 'ip',           wave: '3.2.4.7.5.6...2.7.', data: ['X', 'X+2', 'Y', 'Y+2', 'Z', 'Z+2', 'Z+4', 'Y+2']},
    {name: 'load_ip',      wave: '01010101010..10101'}, // phase_fetch | reload_ip
    {name: 'Source A',     wave: '2.2.2.2.2.2.2.2.2.', data: ['ip', 'ip', 'ip', 'ip', 'ip', 'stack[0]', 'ip', 'cstack[0]', 'ip']},
    {name: 'Source B',     wave: 'x.2.......2.......', data: ['imm', 'stack[1]']},
  	{name: 'ALU',          wave: '22x2222222x222x222', data: ['A', 'A+2', 'B', 'A', 'A+2', 'A', 'B', 'A', 'A+2', 'A+B',   'A', 'A+2', 'A', 'A', 'A+2']},
    {name: 'alu_out',      wave: '32x4.7.5.6x262x7.8', data: ['X', 'X+2', 'Y', 'Y+2', 'Z', 'Z+2', 'S2', 'Z+2', 'Z+4', 'Y+2', 'Y+4']},
    {name: 'mem_out',      wave: 'x3x.4.7.5.6x.6x..7', data: ['ins1', 'ins2', 'ins5', 'ins3', 'ins4', 'ins4', 'ins5', 'ins5']},
    {name: 'insn',         wave: 'x.3...4...5...6...', data: ['ins1: JMP Y', 'ins2: CALL Z', 'ins3: ADD', 'ins4: RET']},
    {name: 'insn_ip',      wave: 'x.1.......0.......',},
    {name: 'stack[0]',     wave: '2...........2.....', data: ['S0', 'S2=S0+S1']},
    {name: 'stack[1]',     wave: '2...........x.....', data: ['S1']},
    {name: 'insn_cpop',    wave: 'x.0...........1...', data: ['S1']},
    {name: 'insn_cpush',   wave: 'x.0...1...0.......', data: ['S1']},
    {name: 'cstack[0]',    wave: 'x......7........x.', data: ['Y+2']},
    {name: 'phase_decode', wave: '0.10..10..10..10..'}, // phase == 0
    {name: 'phase_exec',   wave: '0..10..10..10..10.'}, // phase == 1
    {name: 'phase_rdmem',  wave: '10..10..10..10..10'}, // phase == 2
    {name: 'phase_fetch',  wave: '010..10..10..10..1'}, // phase == 3
    {name: 'reload_ip',    wave: '0..10..10......10.'}, // insn_br & phase_exec
    {name: 'phase_half',   wave: '0.1.0.1.0.1.0.1.0.'}, // phase_decode | phase_exec
    {name: 'sel_a_ip',     wave: '1.........0.1.0.1.'}, // insn_ip | ~phase_half
    {name: 'sel_a_cstack', wave: '0.............1.0.'}, // insn_cpop & phase_half
    {name: 'sel_a_stack0', wave: '0.........1.0.....'}, // sel_a_ip, sel_a_fp, sel_a_cstack がいずれも 0 のとき
  ],
}
