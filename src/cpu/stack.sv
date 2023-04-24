`include "common.sv"

module stack#(
  parameter WIDTH = 16,
  parameter DEPTH = 16
) (
  input rst,
  input clk,
  input pop,
  input push,
  input [WIDTH-1:0] data_in,
  output [WIDTH-1:0] data_out,
  output [WIDTH-1:0] data_raw[0:DEPTH-1]
);

logic [WIDTH-1:0] data[0:DEPTH-1];
assign data_out = data[0];

integer i;

always @(posedge clk, posedge rst) begin
  if (rst)
    for (i = 0; i < DEPTH; i = i+1) data[i] <= {WIDTH{1'b0}};
  else if (pop & ~push) begin
    for (i = 0; i < DEPTH-1; i = i+1) data[i] <= data[i + 1];
    data[DEPTH-1] <= {WIDTH{1'b0}};
  end
  else if (~pop & push) begin
    data[0] <= data_in;
    for (i = 1; i < DEPTH; i = i+1) data[i] <= data[i - 1];
  end
  else if (pop & push)
    data[0] <= data_in;
end

endmodule
