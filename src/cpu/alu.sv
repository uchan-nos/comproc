`include "common.sv"

/*
ALU 機能

番号  名前  説明
----------------
00h   A     A
01h   INC   A + 1
02h   INC2  A + 2
03h   INC3  A + 3
04h   NOT   ~A
0fh   B     B
10h   AND   A & B
11h   OR    A | B
12h   XOR   A ^ B
14h   SHR   A >> B
15h   SAR   A >> B (符号付きシフト)
16h   SHL   A << B
17h   JOIN  A | (B << 8)
20h   ADD   A + B
21h   SUB   A - B
22h   MUL   A * B
28h   LT    A < B
29h   EQ    A == B
2ah   NEQ   A != B
2bh   LE    A <= B
30h   ADDZ  cond ? A : A+B
31h   ADDNZ cond ? A+B : A
*/

module alu#(
  parameter WIDTH = 16
) (
  input [WIDTH-1:0] a,
  input [WIDTH-1:0] b,
  input cond,
  input [5:0] sel,
  output [WIDTH-1:0] out
);

assign out = alu(a, b, cond, sel);

function [WIDTH-1:0] alu(
  input [WIDTH-1:0] a,
  input [WIDTH-1:0] b,
  input cond,
  input [5:0] sel);
begin
  logic [WIDTH-1:0] add, sub;
  logic of;
  logic zf;
  logic sf; // sign flag
  logic lt; // less than
  logic signed [WIDTH-1:0] sa;
  add = a + b;
  sub = a - b;
  of = is_overflow(a[15], b[15], sub[15]);
  zf = sub == {WIDTH{1'b0}};
  sf = sub[15];
  lt = sf ^ of;
  sa = a;
  casex (sel)
    6'b0000xx: alu = a + sel[1:0];
    6'b0001xx: alu = ~a;
    6'b001xxx: alu = b;
    6'b010000: alu = a & b;
    6'b010001: alu = a | b;
    6'b01001x: alu = a ^ b;
    6'b010100: alu = a >> b;
    6'b010101: alu = sa >>> b;
    6'b010110: alu = a << b;
    6'b010111: alu = a | (b << 8);
    6'b100000: alu = add;
    6'b100001: alu = sub;
    6'b100010: alu = a * b;
    6'b101000: alu = lt;
    6'b101001: alu = {{WIDTH-1{1'b0}}, zf};
    6'b101010: alu = {{WIDTH-1{1'b0}}, ~zf};
    6'b101011: alu = lt | zf;
    6'b11xxx0: alu = cond ? a : add;
    6'b11xxx1: alu = cond ? add : a;
    default:   alu = {WIDTH{1'b0}};
  endcase
end
endfunction

function is_overflow(input a, input b, input a_sub_b);
begin
  is_overflow = (a & ~b & ~a_sub_b) | (~a & b & a_sub_b);
end
endfunction

endmodule

