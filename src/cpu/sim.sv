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
integer ip_init = 0;

string uart_in_file;
integer uart_in_fd;
string uart_out_file = "";
integer uart_out = 0;
string pmem_file, dmem_file;
integer dmem_file_fd;
logic [7:0] uart_in[0:255];
logic [15:0] uart_buf;
logic [17:0] insn_buf;
logic [5:0][7:0] insn_name;
integer uart_index, uart_in_len;
integer uart_in_tx_phase;
logic mcu_uart_rx, mcu_uart_tx;
logic [7:0] cur_uart_in;

logic [7:0] mcu_uart_tx_data;
logic mcu_uart_tx_full;

logic [1:0] phase_num;
assign phase_num = mcu.cpu.signals.phase_decode ? 0
                   : mcu.cpu.signals.phase_exec ? 1
                   : mcu.cpu.signals.phase_rdmem ? 2 : 3;

assign cur_uart_in = uart_in[uart_index];

// CPU を接続する
logic rst, clk;
mcu#(.CLOCK_HZ(CLOCK_HZ), .UART_BAUD(UART_BAUD)) mcu(
  .*,
  .uart_rx(mcu_uart_rx), .uart_tx(mcu_uart_tx), .insn(), .load_insn(),
  .ip(), .phase(), .load_ip(), .uart_recv_data(), .img_pmem_size(),
  .clk125(1'b0), .adc_cmp(1'b0), .adc_sh_ctl(), .adc_dac_pwm(),
  .uf_xadr(), .uf_yadr(),
  .uf_xe(), .uf_ye(), .uf_se(), .uf_erase(), .uf_prog(), .uf_nvstr(),
  .uf_din(), .uf_dout(32'hDEADBEEF),
  .spi_cs(), .spi_sclk(), .spi_mosi(), .spi_miso(1'b0)
);

// 実行トレース機能
logic trace_enable;
string trace_file;
integer trace_fd;

initial begin
  // stdin からテストデータを読む
  //while ($fscanf(STDIN, "%x", insn_buf) == 1) begin
  //  mcu.pmem.mem[ip_init] <= insn_buf;
  //  num_insn++;
  //  ip_init++;
  //end
  if ($value$plusargs("pmem=%s", pmem_file))
    $readmemh(pmem_file, mcu.pmem.mem);
  if ($value$plusargs("dmem=%s", dmem_file)) begin
    dmem_file_fd = $fopen(dmem_file, "r");
    uart_index = 16'h100 >> 1;
    while ($fscanf(dmem_file_fd, "%h", uart_buf) == 1) begin
      dmem.mem_lo[uart_index] = uart_buf[7:0];
      dmem.mem_hi[uart_index] = uart_buf[15:8];
      uart_index += 1;
    end
  end

  uart_in_tx_phase = 0;
  mcu_uart_rx = 1;

  uart_index = 0;
  uart_in_len = 0;
  if ($value$plusargs("uart_in=%s", uart_in_file)) begin
    uart_in_fd = $fopen(uart_in_file, "r");
    if (uart_in_fd != 0)
      while ($fscanf(uart_in_fd, "%h", uart_buf) == 1) begin
        uart_in[uart_in_len] = uart_buf;
        uart_in_len += 1;
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
           " alu_out=%04x stack{%02x %02x} in=%04x fp=%04x",
           mcu.cpu.alu_out, stack0, stack1, mcu.cpu.stack_in, mcu.cpu.fp,
           //" cstk{%02x %02x} irq=%d cdt=%04x",
           //mcu.cpu.cstack.data[0], mcu.cpu.cstack.data[1], mcu.cpu.irq, mcu.cdtimer_cnt,
           " mcu_uart_rx=%d cur_uart_in=%02x rx_data=%x rx_full=%d",
           mcu_uart_rx, cur_uart_in, mcu.uart_mux.rx_data, mcu.uart_mux.rx_full
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
  if (mcu_uart_tx_full) begin
    if (uart_out == 0 || mcu_uart_tx_data == 4) begin
      $fdisplay(STDERR, "%x", mcu_uart_tx_data);
      $finish;
    end
    else
      $fwrite(uart_out, "%c", mcu_uart_tx_data);
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
              mcu.cpu.signals.alu_sel, mcu.cpu.src_a_sel, mcu.cpu.src_b_sel,
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

logic [15:0] bram_rd_data;
dmem dmem(
  .rst(rst),
  .clk(clk),
  .addr(mem_addr),
  .wr(wr_mem),
  .byt(byt),
  .wr_data(wr_data),
  .rd_data(bram_rd_data)
);

logic [`ADDR_WIDTH-1:0] mem_addr_d;
assign rd_data = mem_addr_d == `ADDR_WIDTH'h006 ?
                 uart_in[uart_index] : bram_rd_data;

always @(posedge clk) begin
  mem_addr_d <= mem_addr;
end

// MCU への UART 送信
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

// MCU からの UART 受信
uart#(.CLOCK_HZ(CLOCK_HZ), .BAUD(UART_BAUD)) uart(
  .rst(rst),
  .clk(clk),
  .rx(mcu_uart_tx),
  .tx(),
  .rx_data(mcu_uart_tx_data),
  .tx_data(8'hff),
  .rd(mcu_uart_tx_full),
  .rx_full(mcu_uart_tx_full),
  .wr(1'd0),
  .tx_ready()
);

always @(posedge clk) begin
  if (phase_num == 0) begin
    casex (mcu.cpu.insn)
      18'b11_xxxx_xxxx_xxxx_xxxx: insn_name <= "push";
      18'b00_00xx_xxxx_xxxx_xxxx: insn_name <= "call";
      18'b00_0100_xxxx_xxxx_xxxx: insn_name <= "jmp";
      18'b00_0101_xxxx_xxxx_xxxx: insn_name <= "addfp";
      18'b00_0110_xxxx_xxxx_xxx0: insn_name <= "jz";
      18'b00_10xx_xxxx_xxxx_xxxx: insn_name <= "ld1";
      18'b00_11xx_xxxx_xxxx_xxxx: insn_name <= "st1";
      18'b01_00xx_xxxx_xxxx_xxx0: insn_name <= "ld";
      18'b01_00xx_xxxx_xxxx_xxx1: insn_name <= "st";
      18'b01_01xx_xxxx_xxxx_xxxx: insn_name <= "push";
      18'b01_11xx_0000_0000_0000: insn_name <= "nop";
      18'b01_11xx_0000_0100_1111: insn_name <= "pop";
      18'b01_11xx_0000_0100_0000: insn_name <= "pop1";
      18'b01_11xx_0000_0000_0001: insn_name <= "inc";
      18'b01_11xx_0000_0000_0010: insn_name <= "inc2";
      18'b01_11xx_0000_0000_0100: insn_name <= "not";
      18'b01_11xx_0000_0000_0101: insn_name <= "sign";
      18'b01_11xx_0000_0000_0110: insn_name <= "exts";
      18'b01_11xx_0000_0101_0000: insn_name <= "and";
      18'b01_11xx_0000_0101_0001: insn_name <= "or";
      18'b01_11xx_0000_0101_0010: insn_name <= "xor";
      18'b01_11xx_0000_0101_0100: insn_name <= "shr";
      18'b01_11xx_0000_0101_0101: insn_name <= "sar";
      18'b01_11xx_0000_0101_0110: insn_name <= "shl";
      18'b01_11xx_0000_0110_0000: insn_name <= "add";
      18'b01_11xx_0000_0110_0001: insn_name <= "sub";
      18'b01_11xx_0000_0110_0010: insn_name <= "mul";
      18'b01_11xx_0000_0110_1000: insn_name <= "lt";
      18'b01_11xx_0000_0110_1001: insn_name <= "eq";
      18'b01_11xx_0000_0110_1010: insn_name <= "neq";
      18'b01_11xx_0000_1000_0000: insn_name <= "dup";
      18'b01_11xx_0000_1000_1111: insn_name <= "dup1";
      18'b01_11xx_1000_0000_0000: insn_name <= "ret";
      18'b01_11xx_1000_0000_0001: insn_name <= "call";
      18'b01_11xx_1000_0000_0010: insn_name <= "cpop";
      18'b01_11xx_1000_0000_0011: insn_name <= "cpush";
      18'b01_11xx_1000_0000_1000: insn_name <= "ldd";
      18'b01_11xx_1000_0000_1100: insn_name <= "sta";
      18'b01_11xx_1000_0000_1110: insn_name <= "std";
      18'b01_11xx_1000_0000_1001: insn_name <= "ldd1";
      18'b01_11xx_1000_0000_1101: insn_name <= "sta1";
      18'b01_11xx_1000_0000_1111: insn_name <= "std1";
      18'b01_11xx_1000_0001_0000: insn_name <= "int";
      18'b01_11xx_1000_0001_0001: insn_name <= "isr";
      default:                    insn_name <= "UNDEF";
    endcase
  end
end

endmodule
