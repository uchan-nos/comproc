`include "common.sv"

module mcu#(
  parameter CLOCK_HZ = 27_000_000
) (
  input rst, clk, uart_rx,
  input rx_prog, // 1: 最初にプログラムを受信する、0: プログラム受信をスキップ
  output uart_tx,
  output [`ADDR_WIDTH-1:0] mem_addr,
  output wr_mem, byt,
  input  [15:0] rd_data, // メモリ読み込みデータバス
  output [15:0] wr_data, // メモリ書き込みデータバス
  output [15:0] stack0, stack1, insn,
  output [5:0] alu_sel, // デバッグ出力
  output load_insn
  , output logic [15:0] recv_data
  , output logic recv_data_v
  , output dbg_rx_timing
);

logic [`ADDR_WIDTH-1:0] cpu_mem_addr;
logic [15:0] cpu_rd_data, cpu_wr_data;
logic cpu_wr_mem, cpu_byt, cpu_irq;
logic [7:0] uart_rx_data, uart_tx_data;
logic uart_rd, uart_rx_full, uart_wr, uart_tx_ready;

//logic [15:0] recv_data;
logic [`ADDR_WIDTH-1:0] recv_addr;
logic recv_phase, /*recv_data_v, */recv_compl;

//localparam CLK_DIV = 27_000_000 << 1;
//localparam CLK_DIV = 27_000_000 >> 1;
localparam CLK_DIV = 1;
logic [25:0] clk_div_cnt;
logic clk_div, cpu_clk;

logic [15:0] rd_data_d;

always @(posedge rst, posedge clk) begin
  if (rst)
    clk_div_cnt <= 0;
  else if (clk_div_cnt == CLK_DIV - 1)
    clk_div_cnt <= 0;
  else
    clk_div_cnt <= clk_div_cnt + 1;
end

always @(posedge rst, posedge clk) begin
  if (rst)
    clk_div <= 0;
  else if (clk_div_cnt == CLK_DIV - 1)
    clk_div <= 0;
  else if (clk_div_cnt == (CLK_DIV >> 1))
    clk_div <= 1;
end

always @(posedge rst, posedge clk) begin
  if (rst)
    rd_data_d <= 0;
  else if (clk_div_cnt == (CLK_DIV >> 1) + 1)
    rd_data_d <= rd_data;
end

assign cpu_clk = CLK_DIV >= 2 ? clk_div : clk;

cpu#(.CLOCK_HZ(CLOCK_HZ)) cpu(
  .rst(rst | ~recv_compl),
  .clk(cpu_clk),
  .mem_addr(cpu_mem_addr),
  .wr_mem(cpu_wr_mem),
  .byt(cpu_byt),
  .rd_data(cpu_rd_data),
  .wr_data(cpu_wr_data),
  .stack0(stack0),
  .stack1(stack1),
  .insn(insn),
  .load_insn(load_insn),
  .alu_sel(alu_sel),
  .irq(cpu_irq)
);

// MCU 内蔵周辺機能：カウントダウンタイマ
logic cdtimer_to, load_cdtimer, cdtimer_ie;
logic [15:0] data_memreg, data_reg, cdtimer_cnt;

cdtimer#(.PERIOD(CLOCK_HZ/1000)) cdtimer(
  .rst(rst),
  .clk(clk),
  .load(load_cdtimer),
  .data(wr_data),
  .counter(cdtimer_cnt),
  .timeout(cdtimer_to)
);

assign load_cdtimer = cpu_wr_mem & mem_addr === `ADDR_WIDTH'h002;

always @(posedge clk, posedge rst) begin
  if (rst)
    cdtimer_ie <= 1'b0;
  else if (cpu_wr_mem && mem_addr === `ADDR_WIDTH'h004)
    cdtimer_ie <= wr_data[1];
end

// MCU 内蔵周辺機能：UART
uart#(.CLOCK_HZ(CLOCK_HZ), .BAUD(115200), .TIM_WIDTH(8)) uart(
  .rst(rst),
  .clk(clk),
  .rx(uart_rx),
  .tx(uart_tx),
  .rx_data(uart_rx_data),
  .tx_data(uart_tx_data),
  .rd(uart_rd),
  .rx_full(uart_rx_full),
  .wr(uart_wr),
  .tx_ready(uart_tx_ready)
  , .dbg_rx_timing(dbg_rx_timing)
);

assign uart_rd = uart_rx_full;
assign uart_wr = cpu_wr_mem & mem_addr === `ADDR_WIDTH'h006;
assign uart_tx_data = cpu_wr_data[7:0];

// MCU 内蔵周辺機能のメモリマップ
function [15:0] read_memreg(input [`ADDR_WIDTH-1:0] mem_addr);
  casex (mem_addr)
    `ADDR_WIDTH'h002: read_memreg = cdtimer_cnt;
    `ADDR_WIDTH'h004: read_memreg = {14'd0, cdtimer_ie, cdtimer_to};
    `ADDR_WIDTH'h006: read_memreg = recv_data;
    default:          read_memreg = CLK_DIV >= 2 ? rd_data_d : rd_data;
  endcase
endfunction

// 信号結線
assign wr_mem   = ~recv_compl | cpu_wr_mem;
assign byt      = recv_compl ? cpu_byt : 1'b0;
assign mem_addr = recv_compl ? cpu_mem_addr : recv_addr;
assign wr_data  = recv_compl ? cpu_wr_data : recv_data;
assign cpu_rd_data = read_memreg(mem_addr);
assign cpu_irq  = cdtimer_to & cdtimer_ie;

/*
always @(posedge rst, posedge clk) begin
  casex (mem_addr)
    `ADDR_WIDTH'h002: cpu_rd_data = cdtimer_cnt;
    `ADDR_WIDTH'h004: cpu_rd_data = {14'd0, cdtimer_ie, cdtimer_to};
    `ADDR_WIDTH'h006: cpu_rd_data = recv_data;
    default:          cpu_rd_data = rd_data;
  endcase
end
*/

// recv_phase は上位バイトを待っているとき 0、下位バイトを待っているとき 1
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_phase <= 1'b0;
  else if (uart_rx_full)
    recv_phase <= ~recv_phase;
end

// recv_data は UART から受信した直近 2 バイトを記憶する
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_data <= 10'd0;
  else if (uart_rx_full)
    recv_data <= {recv_data[7:0], uart_rx_data};
end

// recv_data_v は命令の受信が完了したら 1 になる
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_data_v <= 1'b0;
  else
    recv_data_v <= uart_rx_full & recv_phase;
end

// recv_addr は命令の受信が完了するたびにインクリメントされる
always @(posedge rst, posedge clk) begin
  if (rst | recv_compl)
    recv_addr <= `ADDR_WIDTH'h300;
  else if (recv_data_v)
    recv_addr <= recv_addr + `ADDR_WIDTH'd2;
end

always @(posedge rst, posedge clk) begin
  if (rst)
    recv_compl <= ~rx_prog;
  else if (recv_data == 16'h7fff)
    recv_compl <= 1'b1;
  else if (recv_phase == 1 && recv_data[7:2] != 6'b0111_11)
    recv_compl <= 1'b0;
end

endmodule
