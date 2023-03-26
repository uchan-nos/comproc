`include "common.sv"

module mem(
  input rst,
  input clk,
  input [`ADDR_WIDTH-1:0] addr,
  input wr,
  input byt,
  input [15:0] wr_data,
  output [15:0] rd_data,

  // BRAM との接続用
  output bram_rst,
  output bram_clk,
  output wr_lo, // write enable for low byte
  output wr_hi, // write enable for high byte
  output [`ADDR_WIDTH-2:0] addr_lo,
  output [`ADDR_WIDTH-2:0] addr_hi,
  output [7:0] wr_data_lo,
  output [7:0] wr_data_hi,
  input [7:0] rd_data_lo,
  input [7:0] rd_data_hi
);

logic addr_lsb;
assign addr_lsb = addr & 1'd1;

assign bram_rst = rst;
assign bram_clk = clk;
assign wr_lo = wr & (~byt | ~addr_lsb);
assign wr_hi = wr & (~byt | addr_lsb);
assign addr_lo = addr >> 1;
assign addr_hi = addr >> 1;
assign wr_data_lo = wr_data[7:0];
assign wr_data_hi = wr_data[15:8];
assign rd_data = {rd_data_hi, rd_data_lo};

endmodule
