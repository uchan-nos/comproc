module cpu(
  input rst,
  input clk,
  input [15:0] insn,
  output logic [7:0] reg0,
  output logic reg0_wr
);

logic [7:0] stack[0:15];

always @(posedge clk, posedge rst) begin
  if (rst)
    reg0 <= 8'd0;
  else if (insn[15:8] == 8'h02)
    reg0 <= stack[0];
end

always @(posedge clk, posedge rst) begin
  if (rst)
    reg0_wr <= 1'b0;
  else if (insn[15:8] == 8'h02)
    reg0_wr <= 1'b1;
  else
    reg0_wr <= 1'b0;
end

integer i;

always @(posedge clk, posedge rst) begin
  if (rst)
    ;
  else if (insn[15:8] == 8'h01) begin
    stack[0] <= insn[7:0];
    for (i = 1; i < 8; i = i+1) stack[i] <= stack[i - 1];
  end
  else if (insn[15:8] == 8'h03) begin
    stack[0] <= stack[1] + stack[0];
    for (i = 1; i < 7; i = i+1) stack[i] <= stack[i + 1];
  end
  else if (insn[15:8] == 8'h04) begin
    stack[0] <= stack[1] - stack[0];
    for (i = 1; i < 7; i = i+1) stack[i] <= stack[i + 1];
  end
  else if (insn[15:8] == 8'h05) begin
    stack[0] <= stack[1] * stack[0];
    for (i = 1; i < 7; i = i+1) stack[i] <= stack[i + 1];
  end
end

endmodule
