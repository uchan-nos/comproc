`include "common.sv"

module mem(
  input rst,
  input clk,
  input [`ADDR_WIDTH-1:0] addr,
  input wr,
  input byt,
  input [15:0] wr_data,
  output [15:0] rd_data
);

logic addr_lsb;
assign addr_lsb = addr & 1'd1;

logic wr_lo, wr_hi;
logic [`ADDR_WIDTH-2:0] addr_lo, addr_hi;
logic [7:0] wr_data_lo, wr_data_hi, rd_data_lo, rd_data_hi;

assign wr_lo = wr & (~byt | ~addr_lsb);
assign wr_hi = wr & (~byt | addr_lsb);
assign addr_lo = addr >> 1;
assign addr_hi = addr >> 1;
assign wr_data_lo = wr_data[7:0];
assign wr_data_hi = wr_data[15:8];
assign rd_data = {rd_data_hi, rd_data_lo};

logic [7:0] mem_lo[0:2047];
logic [7:0] mem_hi[0:2047];

always @(posedge rst, posedge clk) begin
  if (rst) begin
  end
  else begin
    if (wr_lo)
      mem_lo[addr_lo] <= wr_data_lo;
    if (wr_hi)
      mem_hi[addr_hi] <= wr_data_hi;
  end
end

always @(posedge rst, posedge clk) begin
  if (rst) begin
    rd_data_lo <= 0;
    rd_data_hi <= 0;
  end
  else begin
    rd_data_lo <= mem_lo[addr_lo];
    rd_data_hi <= mem_hi[addr_hi];
  end
end

initial begin
  $readmemh("./ipl_lo.hex", mem_lo, `ADDR_WIDTH'h300>>1);
  $readmemh("./ipl_hi.hex", mem_hi, `ADDR_WIDTH'h300>>1);
end

endmodule
