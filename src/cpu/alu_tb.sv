`include "common.sv"

module alu_tb;

logic [15:0] a, b;
logic cond;
logic [5:0] sel;
logic [15:0] out;

alu alu(.*);

initial begin
  $monitor("%d: a=%04x b=%04x cond=%d sel=%02x out=%04x",
           $time, a, b, cond, sel, out);

  a <= 16'hDEAD;
  b <= 16'hBEEF;
  cond <= 1'b0;
  sel <= `ALU_A;

  #1 if (out !== 16'hDEAD) $error("out must be 0xDEAD");

  #1 sel <= `ALU_INC;
  #1 if (out !== 16'hDEAE) $error("out must be 0xDEAE");

  #1 sel <= `ALU_INC2;
  #1 if (out !== 16'hDEAF) $error("out must be 0xDEAF");

  #1 sel <= `ALU_INC3;
  #1 if (out !== 16'hDEB0) $error("out must be 0xDEB0");

  // 0xDEAD  = 0b1101_1110_1010_1101
  // ~0xDEAD = 0b0010_0001_0101_0010
  #1 sel <= `ALU_NOT;
  #1 if (out !== 16'h2152) $error("out must be 0x2152");

  #1 sel <= `ALU_B;
  #1 if (out !== 16'hBEEF) $error("out must be 0xBEEF");

  // 0xDEAD  = 0b1101_1110_1010_1101
  // 0xBEEF  = 0b1011_1110_1110_1111
  #1 sel <= `ALU_AND;
  #1 if (out !== 16'h9EAD) $error("out must be 0x9EAD");

  #1 sel <= `ALU_OR;
  #1 if (out !== 16'hFEEF) $error("out must be 0xFEEF");

  #1 sel <= `ALU_XOR;
  #1 if (out !== 16'h6042) $error("out must be 0x6042");

  #1 sel <= `ALU_SHR; b <= 16'h4;
  #1 if (out !== 16'h0DEA) $error("out must be 0x0DEA");

  #1 sel <= `ALU_SHL;
  #1 if (out !== 16'hEAD0) $error("out must be 0xEAD0");

  #1 sel <= `ALU_SAR;
  #1 if (out !== 16'hFDEA) $error("out must be 0xFDEA");

  #1 b <= 16'd16;
  #1 if (out !== 16'hFFFF) $error("out must be 0xFFFF");

  #1 sel <= `ALU_JOIN; a <= 16'h00FE; b <= 16'h00CA;
  #1 if (out !== 16'hCAFE) $error("out must be 0xCAFE");

  #1 sel <= `ALU_ADD; a <= 16'h2101; b <= 16'h70FF;
  #1 if (out !== 16'h9200) $error("out must be 0x9200");

  #1 sel <= `ALU_SUB;
  #1 if (out !== 16'hB002) $error("out must be 0xB002");

  #1 sel <= `ALU_MUL;
  #1 if (out !== 16'h4FFF) $error("out must be 0x4FFF");

  #1 sel <= `ALU_LT;
  #1 if (out !== 16'h0001) $error("out must be 0x0001");

  #1 sel <= `ALU_EQ;
  #1 if (out !== 16'h0000) $error("out must be 0x0000");

  #1 sel <= `ALU_NEQ;
  #1 if (out !== 16'h0001) $error("out must be 0x0001");

  #1 sel <= `ALU_ADDZ;
  #1 if (out !== 16'h9200) $error("out must be 0x9200"); // 9200 = a+b

  #1 cond <= 1'b1;
  #1 if (out !== 16'h2101) $error("out must be 0x2101");

  #1 sel <= `ALU_ADDNZ;
  #1 if (out !== 16'h9200) $error("out must be 0x9200"); // 9200 = a+b

  #1 cond <= 1'b0;
  #1 if (out !== 16'h2101) $error("out must be 0x2101");
end

endmodule
