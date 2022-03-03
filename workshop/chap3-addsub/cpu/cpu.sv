module cpu(
  input rst,
  input clk,
  input [15:0] insn,
  output logic [7:0] reg0,
  output logic reg0_wr
);

always @(posedge clk, posedge rst) begin
  if (rst)
    reg0 <= 8'd0;
  else if (insn[15:8] == 8'h01)
    reg0 <= insn[7:0];
  else if (insn[15:8] == 8'h03)
    reg0 <= reg0 + insn[7:0];
end

always @(posedge clk, posedge rst) begin
  if (rst)
    reg0_wr <= 1'b0;
  else if (insn[15:8] == 8'h02)
    reg0_wr <= 1'b1;
  else
    reg0_wr <= 1'b0;
end

endmodule
