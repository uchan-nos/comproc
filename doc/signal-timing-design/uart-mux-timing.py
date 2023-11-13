{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPP'},
    {name: 'uart.rx_data', wave: '2...3..4....2...', data: ['61', '55', 'AA', '63']},
    {name: 'uart.rx_full', wave: '1.0.10.1.0..10..'},
    {name: 'uart.rd',      wave: '010.10..10..10..'},
    {name: 'rx_buf',       wave: '2.2..3...4...2..', data: ['60', '61', '55', 'AA', '63']},
    {name: 'rx_buf_full',  wave: '101.01..01..01.0'},
    {name: 'rd_rx_buf',    wave: '10.10..10..10.10'},
    {name: 'rx_data',      wave: 'x2..2...3...4..2', data: ['60', '61', '55', 'AA', '63']},
    {name: 'rx_full',      wave: '01.01.0.1..01.01'},
    {name: 'rd',           wave: '0.10.10...10.10.'},
    {name: 'tim_lt_min',   wave: '0....1...0......'},
    {name: 'rx_buf_55',    wave: '0....1...0......'},
    {name: 'recv_55aa',    wave: '0......1.0......'},
    {name: 'prog_recv',    wave: '0...............'},
  ],
}
