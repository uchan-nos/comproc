module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam TIMEOUT = 10000;

logic [15:0] sim_input[0:1023];
logic [15:0] insn;
logic [9:0] pc;
logic [7:0] mem_addr, rd_data, wr_data;
logic mem_wr;
logic [7:0] stack[0:15];

integer num_insn = 0;

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", sim_input[num_insn]) == 1)
    num_insn++;

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d pc=%02x insn=%04x mem[%02x]=%02x wr=%d phase=%d stack{%02x %02x %02x %02x ..}",
           $time, rst, pc, insn, mem_addr, rd_data, mem_wr, cpu.phase, cpu.stack[0], cpu.stack[1], cpu.stack[2], cpu.stack[3]);

  // 各信号の初期値
  rst <= 1;
  clk <= 1;

  // 13 単位時間後にリセットを解除
  #13
    rst <= 0;
end

// 5 単位時間ごとに clk を反転（クロック周期は 10 単位時間となる）
always #5 begin
  clk <= ~clk;
end

// レジスタに出力があるか、タイムアウトしたらシミュレーション終了
always @(posedge clk) begin
  if (mem_wr & mem_addr == 8'h01) begin
    $fdisplay(STDERR, "%x", wr_data);
    $finish;
  end
  else if ($time > TIMEOUT) begin
    $fdisplay(STDERR, "timeout");
    $finish;
  end
end

// 命令メモリから命令を読み出す
always @(posedge clk) begin
  insn <= sim_input[pc];
end

// CPU を接続する
logic rst, clk;
cpu cpu(.*);

logic [7:0] data_mem[0:255];

always @(posedge clk) begin
  if (mem_wr)
    data_mem[mem_addr] <= wr_data;
end

always @(posedge clk) begin
  rd_data <= data_mem[mem_addr];
end

endmodule
