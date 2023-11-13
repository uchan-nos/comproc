{
  signal: [
    {name: 'clk',          wave: 'PPPPPPPPPPPPPPPP'},
    {name: 'uart.rx_data', wave: '3.|.4..5...|.2..', data: ['55', 'AA', '55', 'AA']},
    {name: 'uart.rx_full', wave: '0.|.10.10..|.10.'},
    {name: 'uart.rd',      wave: '0.|.10.10..|....'},
    {name: 'rx_buf',       wave: '3.|..4..5..|..2.', data: ['55          ', 'AA', '55', 'AA']},
    {name: 'rx_buf_full',  wave: '1.|.01.01..|..0.'},
    {name: 'rd_rx_buf',    wave: '0.|10.10...|....'},
    {name: 'rx_data',      wave: 'x.|.3..4...|..x.', data: ['55', 'AA']},
    {name: 'rx_full',      wave: '0.|.1.01..0|....'},
    {name: 'rd',           wave: '0.|..10..10|....'},
    {name: 'tim_lt_min',   wave: '01|0.......|1.0.'},
    {name: 'tim_gt_max',   wave: '01|0.......|1.0.'},
    {name: 'rx_buf_55',    wave: '1.|..0..1..|..0.'},
    {name: 'recv_55aa',    wave: '0.|.10.....|.10.'},
    {name: 'prog_recv',    wave: '0.|........|..1.'},
  ],
}
