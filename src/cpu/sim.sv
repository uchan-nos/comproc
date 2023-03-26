`include "common.sv"
module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam CLOCK_HZ = 10_000;
localparam TIMEOUT = 1 * CLOCK_HZ * 10; // 1 秒間でタイムアウト

logic [9:0] mem_addr;
logic [15:0] rd_data, wr_data;
logic mem_wr;
logic mem_byt;
logic [15:0] stack[0:15];

logic [15:0] wr_data_mon;
assign wr_data_mon = mem_wr ? cpu.wr_data : 16'hzzzz;

integer num_insn = 0;
integer pc_init = 10'h100;

string uart_in_file;
string uart_out_file = "";
integer uart_out = 0;
integer uart_eot = 0;
logic [15:0] uart_in[0:255];
logic [5:0][7:0] insn_name;
integer uart_index;

logic [15:0] insn_buf;

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", insn_buf) == 1) begin
    mem_lo.data[pc_init] <= insn_buf[7:0];
    mem_hi.data[pc_init] <= insn_buf[15:8];
    num_insn++;
    pc_init++;
  end

  for (uart_index = 0; uart_index < 256; uart_index++) uart_in[uart_index] = 0;
  uart_index = 0;
  if ($value$plusargs("uart_in=%s", uart_in_file))
    $readmemh(uart_in_file, uart_in);
  if ($value$plusargs("uart_out=%s", uart_out_file))
    uart_out = $fopen(uart_out_file, "w");

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d pc=%02x.%d %04x %-6s mem[%02x]=%04x wr=%04x byt=%d alu=%02x stack{%02x %02x %02x %02x ..} bp=%04x fp=%04x cdt=%04x cdtms=%04x",
           $time, rst, cpu.pc, cpu.phase, cpu.insn, insn_name, mem_addr, rd_data,
           wr_data_mon, cpu.mem_byt, cpu.alu_out,
           cpu.stack[0], cpu.stack[1], cpu.stack[2], cpu.stack[3], cpu.bp, cpu.fp,
           cpu.cd_timer, cpu.cd_timer_ms);

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
  if (mem_wr && mem_addr == 10'h01e) begin
    if (uart_out == 0 || uart_eot != 0) begin
      $fdisplay(STDERR, "%x", wr_data[7:0]);
      $finish;
    end
    if (wr_data[7:0] == 4)
      uart_eot = 1;
    else
      $fwrite(uart_out, "%c", wr_data[7:0]);
  end
  else if ($time > TIMEOUT) begin
    $fdisplay(STDERR, "timeout");
    $finish;
  end
end

// CPU を接続する
logic rst, clk;
cpu#(.CLOCK_HZ(100_000)) cpu(.*);

logic bram_clk, bram_rst, wr_lo, wr_hi;
logic [`ADDR_WIDTH-2:0] addr_lo, addr_hi;
logic [7:0] wr_data_lo, wr_data_hi, rd_data_lo, rd_data_hi;
logic [15:0] bram_rd_data;
mem mem(
  .rst(rst),
  .clk(clk),
  .addr(mem_addr),
  .wr(mem_wr),
  .byt(mem_byt),
  .wr_data(wr_data),
  .rd_data(bram_rd_data),

  .bram_rst(bram_rst),
  .bram_clk(bram_clk),
  .wr_lo(wr_lo),
  .wr_hi(wr_hi),
  .addr_lo(addr_lo),
  .addr_hi(addr_hi),
  .wr_data_lo(wr_data_lo),
  .wr_data_hi(wr_data_hi),
  .rd_data_lo(rd_data_lo),
  .rd_data_hi(rd_data_hi)
);

byte_bram mem_lo(
  .rst(bram_rst),
  .clk(bram_clk),
  .wr(wr_lo),
  .addr(addr_lo),
  .wr_data(wr_data_lo),
  .rd_data(rd_data_lo)
);

byte_bram mem_hi(
  .rst(bram_rst),
  .clk(bram_clk),
  .wr(wr_hi),
  .addr(addr_hi),
  .wr_data(wr_data_hi),
  .rd_data(rd_data_hi)
);

assign rd_data = mem_addr == `ADDR_WIDTH'h01e ?
                 uart_in[uart_index] : bram_rd_data;

always #5000 begin
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
        8'h14: insn_name <= "shr";
        8'h15: insn_name <= "shl";
        8'h16: insn_name <= "sar";
        default: insn_name <= "UNDEF";
      endcase
    else
      casex (cpu.insn)
        16'b0xxxxxxx_xxxxxxxx: insn_name <= "push";
        16'h81xx:              insn_name <= "pop";
        16'h82xx:              insn_name <= "dup";
        16'h90xx:              insn_name <= "ld";
        16'h91xx:              insn_name <= "ldd";
        16'h94xx:              insn_name <= "st";
        16'h95xx:              insn_name <= "sta";
        16'h96xx:              insn_name <= "std";
        16'h98xx:              insn_name <= "ld.1";
        16'h99xx:              insn_name <= "ldd.1";
        16'h9cxx:              insn_name <= "st.1";
        16'h9dxx:              insn_name <= "sta.1";
        16'h9exx:              insn_name <= "std.1";
        16'ha0xx:              insn_name <= "jmp";
        16'ha1xx:              insn_name <= "jz";
        16'ha2xx:              insn_name <= "jnz";
        16'ha3xx:              insn_name <= "call";
        16'ha4xx:              insn_name <= "ret";
        16'hc020:              insn_name <= "pushbp";
        16'hc1xx:              insn_name <= "popfp";
        16'hc221:              insn_name <= "enter";
        16'hc320:              insn_name <= "leave";
        default:               insn_name <= "UNDEF";
      endcase
  end
end

endmodule

module byte_bram(
  input rst,
  input clk,
  input wr,
  input [`ADDR_WIDTH-2:0] addr,
  input [7:0] wr_data,
  output [7:0] rd_data
);
logic [7:0] data[0:(1<<(`ADDR_WIDTH-1))-1];
assign rd_data = data[addr];
always @(posedge clk) begin
  if (wr)
    data[addr] <= wr_data;
end
endmodule
