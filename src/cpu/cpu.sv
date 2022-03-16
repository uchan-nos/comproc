module cpu(
  input rst,
  input clk,
  input [15:0] insn,
  output logic [7:0] reg0,
  output logic reg0_wr,
  output logic [9:0] pc,
  output [7:0] mem_addr,
  output logic mem_wr,
  input        [7:0] rd_data,
  output logic [7:0] wr_data
);

logic [7:0] stack[0:15];
logic phase; // 0=命令実行 1=メモリアクセス

assign mem_addr = insn[7:0];

always @(posedge clk, posedge rst) begin
  if (rst)
    reg0 <= 8'd0;
  else if (~phase && insn[15:8] == 8'h02)
    reg0 <= stack[0];
end

always @(posedge clk, posedge rst) begin
  if (rst)
    reg0_wr <= 1'b0;
  else if (~phase && insn[15:8] == 8'h02)
    reg0_wr <= 1'b1;
  else
    reg0_wr <= 1'b0;
end

integer i;

// 演算用スタックを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    ;
  else if (phase)
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
  else if (insn[15:8] == 8'h06) begin
    for (i = 0; i < 7; i = i+1) stack[i] <= stack[i + 1];
  end
  else if (insn[15:8] == 8'h07) begin
    stack[0] <= rd_data;
    for (i = 1; i < 8; i = i+1) stack[i] <= stack[i - 1];
  end
end

// メモリ書き込み命令だったら mem_wr を有効化する
always @(posedge clk, posedge rst) begin
  if (rst)
    mem_wr <= 1'b0;
  else if (~phase && insn[15:8] == 8'h06)
    mem_wr <= 1'b1;
  else
    mem_wr <= 1'b0;
end

// メモリに書き込むためのデータを wr_data に設定
always @(posedge clk, posedge rst) begin
  if (rst)
    wr_data <= 8'd0;
  else if (phase)
    wr_data <= stack[0];
end

// 命令実行フェーズを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    phase <= 1'b0;
  else
    phase <= ~phase;
end

// 命令実行が完了したらプログラムカウンタを進める
always @(posedge clk, posedge rst) begin
  if (rst)
    pc <= 10'd0;
  else if (phase)
    pc <= pc + 10'd1;
end

endmodule
