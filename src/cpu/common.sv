`define ADDR_WIDTH 12

`define ALU_A     6'h00
`define ALU_INC   6'h01
`define ALU_INC2  6'h02
`define ALU_INC3  6'h03
`define ALU_NOT   6'h04
`define ALU_B     6'h0f
`define ALU_AND   6'h10
`define ALU_OR    6'h11
`define ALU_XOR   6'h12
`define ALU_SHR   6'h14
`define ALU_SAR   6'h15
`define ALU_SHL   6'h16
`define ALU_JOIN  6'h17
`define ALU_ADD   6'h20
`define ALU_SUB   6'h21
`define ALU_MUL   6'h22
`define ALU_LT    6'h28
`define ALU_EQ    6'h29
`define ALU_NEQ   6'h2a
`define ALU_ADDZ  6'h30
`define ALU_ADDNZ 6'h31

// Source A
`define SRC_STK0 2'h0
`define SRC_FP   2'h1
`define SRC_IP   2'h2
`define SRC_CSTK 2'h3

// Source B
`define SRC_STK1 2'h0
`define SRC_IMM  2'h1
`define SRC_ISR  2'h2

`define SRC_X    2'hx
