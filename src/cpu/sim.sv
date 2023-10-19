`include "common.sv"
module Simulation;

localparam STDIN  = 'h8000_0000;
localparam STDERR = 'h8000_0002;
localparam CLOCK_HZ = 100_000;
localparam UART_BAUD = 1_000;
localparam TIMEOUT = 1 * CLOCK_HZ * 10; // 1 秒間でタイムアウト

logic [`ADDR_WIDTH-1:0] mem_addr;
logic [15:0] rd_data, wr_data;
logic wr_mem;
logic byt;
logic [15:0] stack0, stack1;
logic [5:0] alu_sel;

logic [15:0] wr_data_mon;
assign wr_data_mon = wr_mem ? mcu.wr_data : 16'hzzzz;

integer num_insn = 0;
integer ip_init = `ADDR_WIDTH'h300 >> 1;

string uart_in_file;
integer uart_in_fd;
string uart_out_file = "";
integer uart_out = 0;
integer uart_eot = 0;
logic [7:0] uart_in[0:255];
logic [15:0] uart_buf;
logic [5:0][7:0] insn_name;
integer uart_index, uart_in_len;
integer uart_in_tx_phase;
logic mcu_uart_rx;
logic [7:0] cur_uart_in;

logic [15:0] insn_buf;

logic [1:0] phase_num;
assign phase_num = mcu.cpu.signals.phase_decode ? 0
                   : mcu.cpu.signals.phase_exec ? 1
                   : mcu.cpu.signals.phase_rdmem ? 2 : 3;
logic [1:0] src_a_sel;
assign src_a_sel = mcu.cpu.src_a_fp ? 2'd1
                   : mcu.cpu.src_a_ip ? 2'd2
                   : mcu.cpu.src_a_cstk ? 2'd3 : 2'd0;

assign cur_uart_in = uart_in[uart_index];

// CPU を接続する
logic rst, clk;
mcu#(.CLOCK_HZ(CLOCK_HZ), .UART_BAUD(UART_BAUD)) mcu(
  .*,
  .uart_rx(mcu_uart_rx), .rx_prog(1'b0), .uart_tx(), .insn(), .load_insn(),
  .recv_data(), .recv_data_v()
);

// 実行トレース機能
logic trace_enable;
string trace_file;
integer trace_fd;

initial begin
  // stdin からテストデータを読む
  while ($fscanf(STDIN, "%x", insn_buf) == 1) begin
    mem_lo.data[ip_init] <= insn_buf[7:0];
    mem_hi.data[ip_init] <= insn_buf[15:8];
    num_insn++;
    ip_init++;
  end

  uart_in_tx_phase = 0;
  mcu_uart_rx = 1;

  uart_index = 0;
  uart_in_len = 0;
  if ($value$plusargs("uart_in=%s", uart_in_file)) begin
    uart_in_fd = $fopen(uart_in_file, "r");
    if (uart_in_fd != 0)
      while ($fscanf(uart_in_fd, "%h", uart_buf) == 1) begin
        uart_in[uart_in_len] = uart_buf[15:8];
        uart_in[uart_in_len+1] = uart_buf[7:0];
        uart_in_len += 2;
      end
  end
  if ($value$plusargs("uart_out=%s", uart_out_file))
    uart_out = $fopen(uart_out_file, "w");
  if ($value$plusargs("trace_file=%s", trace_file))
    trace_fd = $fopen(trace_file, "w");

  // 信号が変化したら自動的に出力する
  $monitor("%d: rst=%d ip=%02x.%d %04x %-6s",
           $time, rst, mcu.cpu.ip, phase_num, mcu.cpu.insn, insn_name,
           " addr=%03x r=%04x w=%04x byt=%d",
           mem_addr, rd_data, wr_data_mon, byt,
           " alu_out=%04x stack{%02x %02x} fp=%04x",
           mcu.cpu.alu_out, stack0, stack1, mcu.cpu.fp,
           //" cstk{%02x %02x} irq=%d cdt=%04x",
           //mcu.cpu.cstack.data[0], mcu.cpu.cstack.data[1], mcu.cpu.irq, mcu.cdtimer_cnt,
           " mcu_uart_rx=%d cur_uart_in=%02x rx_shift=%x, rx_data=%x rx_full=%d",
           mcu_uart_rx, cur_uart_in, mcu.uart.rx_shift, mcu.uart.rx_data, mcu.uart.rx_full
         );
  $dumpvars(1, mcu.cpu, mcu.cpu.signals.decoder);

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
  if (wr_mem && mem_addr == `ADDR_WIDTH'h006) begin
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

// トレース情報を出力
always @(posedge clk) begin
  if (trace_fd != 0) begin
    $fdisplay(trace_fd,
              // メタデータ
              "%d rst=%d phase=%d ",
              $stime, rst, phase_num,
              // レジスタ値
              "stack0=%x fp=%x ip=%x insn=%x cstack0=%x ",
              stack0, mcu.cpu.fp, mcu.cpu.ip, mcu.cpu.insn, mcu.cpu.cstack0,
              // セレクト信号
              "alu_sel=%x src_a_sel=%x src_b_sel=%x ",
              mcu.cpu.signals.alu_sel, src_a_sel, mcu.cpu.src_b_sel,
              "rd_mem=%x wr_stk1=%x ",
              mcu.cpu.rd_mem, mcu.cpu.wr_stk1,
              // 制御信号
              "pop=%x push=%x load_stk=%x load_fp=%x load_ip=%x ",
              mcu.cpu.pop, mcu.cpu.push, mcu.cpu.load_stk, mcu.cpu.load_fp, mcu.cpu.load_ip,
              "load_isr=%d cpop=%x cpush=%x ",
              mcu.cpu.load_isr, mcu.cpu.cpop, mcu.cpu.cpush,
              // データ値
              "rd_data=%x wr_data=%x addr_d=%x ",
              rd_data, wr_data, mcu.cpu.addr_d,
              "alu_out=%x src_a=%x src_b=%x stack_in=%x imm_mask=%x ",
              mcu.cpu.alu_out, mcu.cpu.src_a, mcu.cpu.src_b, mcu.cpu.stack_in, mcu.cpu.imm_mask
             );
  end
end

logic bram_clk, bram_rst, wr_lo, wr_hi;
logic [`ADDR_WIDTH-2:0] addr_lo, addr_hi;
logic [7:0] wr_data_lo, wr_data_hi, rd_data_lo, rd_data_hi;
logic [15:0] bram_rd_data;
mem mem(
  .rst(rst),
  .clk(clk),
  .addr(mem_addr),
  .wr(wr_mem),
  .byt(byt),
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

logic [`ADDR_WIDTH-1:0] mem_addr_d;
assign rd_data = mem_addr_d == `ADDR_WIDTH'h006 ?
                 uart_in[uart_index] : bram_rd_data;

always @(posedge clk) begin
  mem_addr_d <= mem_addr;
end

// UART 送信のシミュレート
always #(10*CLOCK_HZ/UART_BAUD) begin
  if (uart_index == uart_in_len)
    mcu_uart_rx = 1;
  else begin
    case (uart_in_tx_phase)
      0: mcu_uart_rx = 0; // start bit
      9: mcu_uart_rx = 1; // stop bit
      default: mcu_uart_rx = (uart_in[uart_index] >> (uart_in_tx_phase - 1)) & 1;
    endcase

    if (uart_in_tx_phase < 9)
      uart_in_tx_phase++;
    else begin
      uart_in_tx_phase = 0;
      uart_index++;
    end
  end
end

always @(posedge clk) begin
  if (phase_num == 0) begin
    casex (mcu.cpu.insn)
      16'b1xxx_xxxx_xxxx_xxxx: insn_name <= "push";
      16'b0000_xxxx_xxxx_xxx0: insn_name <= "jmp";
      16'b0000_xxxx_xxxx_xxx1: insn_name <= "call";
      16'b0001_xxxx_xxxx_xxx0: insn_name <= "jz";
      16'b0001_xxxx_xxxx_xxx1: insn_name <= "jnz";
      16'b0010_xxxx_xxxx_xxxx: insn_name <= "ld.1";
      16'b0011_xxxx_xxxx_xxxx: insn_name <= "st.1";
      16'b0100_xxxx_xxxx_xxx0: insn_name <= "ld";
      16'b0100_xxxx_xxxx_xxx1: insn_name <= "st";
      16'b0101_xxxx_xxxx_xxxx: insn_name <= "push";
      16'b0110_01xx_xxxx_xxxx: insn_name <= "addfp";
      16'b0111_0000_0000_0000: insn_name <= "nop";
      16'b0111_0000_0100_1111: insn_name <= "pop";
      16'b0111_0000_0100_0000: insn_name <= "pop1";
      16'b0111_0000_0000_0001: insn_name <= "inc";
      16'b0111_0000_0000_0010: insn_name <= "inc2";
      16'b0111_0000_0000_0100: insn_name <= "not";
      16'b0111_0000_0101_0000: insn_name <= "and";
      16'b0111_0000_0101_0001: insn_name <= "or";
      16'b0111_0000_0101_0010: insn_name <= "xor";
      16'b0111_0000_0101_0100: insn_name <= "shr";
      16'b0111_0000_0101_0101: insn_name <= "sar";
      16'b0111_0000_0101_0110: insn_name <= "shl";
      16'b0111_0000_0101_0111: insn_name <= "join";
      16'b0111_0000_0110_0000: insn_name <= "add";
      16'b0111_0000_0110_0001: insn_name <= "sub";
      16'b0111_0000_0110_0010: insn_name <= "mul";
      16'b0111_0000_0110_1000: insn_name <= "lt";
      16'b0111_0000_0110_1001: insn_name <= "eq";
      16'b0111_0000_0110_1010: insn_name <= "neq";
      16'b0111_0000_1000_0000: insn_name <= "dup";
      16'b0111_0000_1000_1111: insn_name <= "dup1";
      16'b0111_1000_0000_0000: insn_name <= "ret";
      16'b0111_1000_0000_0010: insn_name <= "cpop";
      16'b0111_1000_0000_0011: insn_name <= "cpush";
      16'b0111_1000_0000_1000: insn_name <= "ldd";
      16'b0111_1000_0000_1100: insn_name <= "sta";
      16'b0111_1000_0000_1110: insn_name <= "std";
      16'b0111_1000_0000_1001: insn_name <= "ldd.1";
      16'b0111_1000_0000_1101: insn_name <= "sta.1";
      16'b0111_1000_0000_1111: insn_name <= "std.1";
      16'b0111_1000_0001_0000: insn_name <= "int";
      16'b0111_1000_0001_0001: insn_name <= "isr";
      default:                 insn_name <= "UNDEF";
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
  output logic [7:0] rd_data
);
logic [7:0] data[0:(1<<(`ADDR_WIDTH-1))-1];
always @(posedge clk, posedge rst) begin
  if (rst)
    rd_data <= 8'd0;
  else begin
    rd_data <= data[addr];
    if (wr)
      data[addr] <= wr_data;
  end
end
endmodule
