{
  signal: [
    {name: 'clk',       wave: 'PPPPPPPPPPP'},
    {name: 'I_RX_EN',   wave: '01010101010'},
    {name: 'rx_rdy',    wave: '0....1.0...'},
    {name: 'rx_v',      wave: '0......1.0.'},
    {name: 'I_RADDR',   wave: '2....3.2...', data: ['LSR', 'RBR', 'LSR']},
    {name: 'O_RDATA',   wave: '2....2.3.2.', data: ['0x60', '0x61', 'DAT', '0x60']},
    {name: 'rx_data',   wave: '2.......3..', data: ['0', 'DAT']},
    {name: 'rx_data_wr',wave: '0.......10.'},
  ],
}
