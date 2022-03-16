module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam TIMEOUT = 1000;

logic [15:0] sim_input[0:1023];
logic [15:0] insn;
logic [9:0] pc;
logic [7:0] mem_addr, rd_data, wr_data;
logic mem_wr;

integer num_insn = 0;

assign insn = sim_input[pc];
assign rd_data = data_mem[mem_addr];

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", sim_input[num_insn]) == 1)
    num_insn++;

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d pc=%02x insn=%04x reg0_wr=%d reg0=%02x mem[%02x]=%02x wr=%d stk0=%02x",
           $time, rst, pc, insn, reg0_wr, reg0, mem_addr, rd_data, mem_wr, cpu.stack[0]);

  // 各信号の初期値
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

logic [7:0] data_mem[0:255];

always @(posedge clk) begin
  if (mem_wr)
    data_mem[mem_addr] <= wr_data;
end

endmodule
