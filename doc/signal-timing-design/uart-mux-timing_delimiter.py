{
  signal: [
    {name: 'clk',             wave: 'PPPPPPPPPPPPPPPPPP'},
    {name: 'uart.rx_data',    wave: '3|.4..5...|.2..2..', data: ['55     ', 'AA', '55', 'AA', '23']},
    {name: 'uart.rx_full',    wave: '0|.10.10..|.10.10.'},
    {name: 'uart.rd',         wave: '0|.10.10..|.10.10.'},
    {name: 'rx_buf',          wave: '3|..4..5..|..2..2.', data: ['55               ', 'AA', '55', 'AA', '23']},
    {name: 'rx_buf_full',     wave: '1|.01.01..|..0..10'},
    {name: 'rd_rx_buf',       wave: '0|10.10...|.....10'},
    {name: 'rx_data',         wave: 'x|.3..4...|..x...2', data: ['55', 'AA', '23']},
    {name: 'rx_full',         wave: '0|.1.01..0|......1'},
    {name: 'rd',              wave: '0|..10..10|.......'},
    {name: 'tim < lower',     wave: '0|...1....|0..1...'},
    {name: 'tim > upper',     wave: '0|1..0....|.......'},
    {name: 'rx_buf_55',       wave: '1|..0..1..|..0....'},
    {name: 'recv_55aa',       wave: '0|.10.....|.10....'},
    {name: 'start_prog_recv', wave: '0|........|.10....'},
    {name: 'prog_recv',       wave: '0|........|..1....'},
  ],
}
