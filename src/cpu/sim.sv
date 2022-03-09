module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam TIMEOUT = 1000;

logic [15:0] sim_input[0:1023];
logic [15:0] insn;
logic [9:0] pc;
integer num_insn = 0;

assign insn = sim_input[pc];

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", sim_input[num_insn]) == 1)
    num_insn++;

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d pc=%02x insn=%04x reg0_wr=%d reg0=%02x",
           $time, rst, pc, insn, reg0_wr, reg0);

  // 各信号の初期値
  pc <= 0;
  rst <= 1;
  clk <= 1;

  // 3 単位時間後にリセットを解除
  #3
    rst <= 0;
end

// 5 単位時間ごとに clk を反転（クロック周期は 10 単位時間となる）
always #5 begin
  clk <= ~clk;
end

// クロックの立ち上がりと同時に pc をインクリメント
always @(posedge clk) begin
  if (rst)
    pc <= 0;
  else if (pc < num_insn - 1)
    pc <= pc + 1;
end

// レジスタに出力があるか、タイムアウトしたらシミュレーション終了
always @(posedge clk) begin
  if (reg0_wr) begin
    $fdisplay(STDERR, "%x", reg0);
    $finish;
  end
  else if ($time > TIMEOUT) begin
    $fdisplay(STDERR, "timeout");
    $finish;
  end
end

// CPU を接続する
logic rst, clk, reg0_wr;
logic [7:0] reg0;
cpu cpu(
  .*,
  .insn(sim_input[pc])
);

endmodule
