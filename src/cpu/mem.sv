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

// mem_lo/mem_hi はメモリの前半 32KiB
// memex_lo/memex_hi はメモリの後半 16KiB
logic [7:0] mem_lo[0:`ADDR_WIDTH'h3fff];
logic [7:0] mem_hi[0:`ADDR_WIDTH'h3fff];
logic [7:0] memex_lo[0:`ADDR_WIDTH'h1fff];
logic [7:0] memex_hi[0:`ADDR_WIDTH'h1fff];
//logic [7:0] mem_lo[0:(`ADDR_WIDTH'hBFFF >> 1)];
//logic [7:0] mem_hi[0:(`ADDR_WIDTH'hBFFF >> 1)];

always @(posedge rst, posedge clk) begin
  if (rst) begin
  end
  else if (addr < `ADDR_WIDTH'h8000) begin
    if (wr_lo)
      mem_lo[addr_lo] <= wr_data_lo;
    if (wr_hi)
      mem_hi[addr_hi] <= wr_data_hi;
  end
  else begin
    if (wr_lo)
      memex_lo[addr_lo - `ADDR_WIDTH'h8000] <= wr_data_lo;
    if (wr_hi)
      memex_hi[addr_hi - `ADDR_WIDTH'h8000] <= wr_data_hi;
  end
end

always @(posedge rst, posedge clk) begin
  if (rst) begin
    rd_data_lo <= 0;
    rd_data_hi <= 0;
  end
  else if (addr < `ADDR_WIDTH'h8000) begin
    rd_data_lo <= mem_lo[addr_lo];
    rd_data_hi <= mem_hi[addr_hi];
  end
  else begin
    rd_data_lo <= memex_lo[addr_lo - `ADDR_WIDTH'h8000];
    rd_data_hi <= memex_hi[addr_hi - `ADDR_WIDTH'h8000];
  end
end

initial begin
  $readmemh("./ipl_lo.hex", mem_lo, `ADDR_WIDTH'h4000>>1);
  $readmemh("./ipl_hi.hex", mem_hi, `ADDR_WIDTH'h4000>>1);
end

endmodule
