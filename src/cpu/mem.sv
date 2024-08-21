`include "common.sv"

module data_mem(
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

logic [7:0] mem_lo[0:13'h1fff];
logic [7:0] mem_hi[0:13'h1fff];

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

endmodule


module text_mem(
  input rst,
  input clk,
  input [`ADDR_WIDTH-1:0] addr,
  input wr,
  input [17:0] wr_data,
  output logic [17:0] rd_data
);

logic [17:0] mem[0:`ADDR_WIDTH'h1fff];

always @(posedge rst, posedge clk) begin
  if (rst) begin
  end
  else if (wr)
    mem[addr] <= wr_data;
end

always @(posedge rst, posedge clk) begin
  if (rst) begin
    rd_data <= 18'd0;
  end
  else
    rd_data <= mem[addr];
end

initial begin
  $readmemh("./ipl.hex", mem, 0);
end

endmodule
