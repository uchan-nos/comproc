module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam TIMEOUT = 10000;

logic [9:0] mem_addr;
logic [15:0] rd_data, wr_data;
logic mem_wr;
logic [15:0] stack[0:15];
logic [15:0] mem[0:1023];

logic [15:0] wr_data_mon;
assign wr_data_mon = mem_wr ? cpu.wr_data : 16'hzzzz;

integer num_insn = 0;
integer pc_init = 10'h100;

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", mem[pc_init]) == 1) begin
    num_insn++;
    pc_init++;
  end

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d pc=%02x.%d %04x mem[%02x]=%04x wr=%04x alu=%02x stack{%02x %02x %02x %02x ..}",
           $time, rst, cpu.pc, cpu.phase, cpu.insn, mem_addr, rd_data, wr_data_mon, cpu.alu_out,
           cpu.stack[0], cpu.stack[1], cpu.stack[2], cpu.stack[3]);

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
    $fdisplay(STDERR, "%x", wr_data[7:0]);
    $finish;
  end
  else if ($time > TIMEOUT) begin
    $fdisplay(STDERR, "timeout");
    $finish;
  end
end

// CPU を接続する
logic rst, clk;
cpu cpu(.*);

always @(posedge clk) begin
  if (mem_wr)
    mem[mem_addr >> 1] <= wr_data;
  else
    rd_data <= mem[mem_addr >> 1];
end

endmodule
