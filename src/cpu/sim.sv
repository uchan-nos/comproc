module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam TIMEOUT = 100000;

logic [9:0] mem_addr;
logic [15:0] rd_data, wr_data;
logic mem_wr;
logic [15:0] stack[0:15];
logic [15:0] mem[0:1023];

logic [15:0] wr_data_mon;
assign wr_data_mon = mem_wr ? cpu.wr_data : 16'hzzzz;

integer num_insn = 0;
integer pc_init = 10'h100;

string uart_in_file;
logic [15:0] uart_in[0:255];
logic [4:0][7:0] insn_name;
integer uart_index;

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", mem[pc_init]) == 1) begin
    num_insn++;
    pc_init++;
  end

  for (uart_index = 0; uart_index < 256; uart_index++) uart_in[uart_index] = 0;
  uart_index = 0;
  if ($value$plusargs("uart_in=%s", uart_in_file)) begin
    $readmemh(uart_in_file, uart_in);
  end

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d pc=%02x.%d %04x %-5s mem[%02x]=%04x wr=%04x alu=%02x stack{%02x %02x %02x %02x ..}",
           $time, rst, cpu.pc, cpu.phase, cpu.insn, insn_name, mem_addr, rd_data, wr_data_mon, cpu.alu_out,
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
  if (mem_wr & mem_addr == 16'h02) begin
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
  else if (mem_addr == 10'h002)
    rd_data <= uart_in[uart_index];
  else
    rd_data <= mem[mem_addr >> 1];
end

always #1000 begin
  uart_index <= uart_index + 1;
end

always @(posedge clk) begin
  if (cpu.phase == 0) begin
    if (cpu.insn[15:8] == 8'hb0)
      case (cpu.insn[7:0])
        8'h02: insn_name <= "add";
        8'h03: insn_name <= "sub";
        8'h04: insn_name <= "mul";
        8'h05: insn_name <= "join";
        8'h08: insn_name <= "lt";
        8'h09: insn_name <= "eq";
        8'h0a: insn_name <= "neq";
        8'h10: insn_name <= "and";
        8'h11: insn_name <= "xor";
        8'h12: insn_name <= "or";
        8'h13: insn_name <= "not";
      endcase
    else
      casex (cpu.insn[15:8])
        8'b0xxxxxxx: insn_name <= "push";
        8'h81:       insn_name <= "pop";
        8'h82:       insn_name <= "dup";
        8'h90:       insn_name <= "ld";
        8'h91:       insn_name <= "ldd";
        8'h94:       insn_name <= "st";
        8'h95:       insn_name <= "sta";
        8'h96:       insn_name <= "std";
        8'h98:       insn_name <= "ld.1";
        8'h99:       insn_name <= "ldd.1";
        8'h9c:       insn_name <= "st.1";
        8'h9d:       insn_name <= "sta.1";
        8'h9e:       insn_name <= "std.1";
        8'ha0:       insn_name <= "jmp";
        8'ha1:       insn_name <= "jz";
        8'ha2:       insn_name <= "jnz";
        default:     insn_name <= "UNDEF";
      endcase
  end
end

endmodule
