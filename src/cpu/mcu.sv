`include "common.sv"

module mcu#(
  parameter CLOCK_HZ = 27_000_000,
  parameter UART_BAUD = 115200
) (
  input rst, clk, uart_rx,
  output uart_tx,
  output [`ADDR_WIDTH-1:0] mem_addr,
  output wr_mem, byt,
  input  [15:0] rd_data, // メモリ読み込みデータバス
  output [15:0] wr_data, // メモリ書き込みデータバス
  output [15:0] stack0, stack1, insn,
  output [5:0] alu_sel, // デバッグ出力
  output load_insn,
  input  clk125,
  input  adc_cmp,     // ADC のコンパレータ出力
  output adc_sh_ctl,  // ADC のサンプル&ホールドスイッチ制御
  output adc_dac_pwm, // ADC の DAC PWM 信号
  output logic [8:0] uf_xadr,
  output logic [5:0] uf_yadr,
  output logic uf_xe, uf_ye, uf_se, uf_erase, uf_prog, uf_nvstr,
  output logic [31:0] uf_din,
  input  [31:0] uf_dout,
  output spi_cs, spi_sclk, spi_mosi,
  input  spi_miso
);

// CPU コア
logic [`ADDR_WIDTH-1:0] cpu_mem_addr, mem_addr_d;
logic [15:0] cpu_rd_data, cpu_wr_data;
logic cpu_rd_mem, cpu_wr_mem, cpu_byt, cpu_irq;
logic cpu_rst;

logic [15:0] recv_data;
logic [`ADDR_WIDTH-1:0] recv_addr;
logic recv_phase, recv_data_v, recv_compl, uart_rx_ready;

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
assign cpu_rst = rst | ~recv_compl;

always @(posedge cpu_clk, posedge rst) begin
  if (rst)
    mem_addr_d <= `ADDR_WIDTH'd0;
  else
    mem_addr_d <= mem_addr;
end

cpu#(.CLOCK_HZ(CLOCK_HZ)) cpu(
  .rst(cpu_rst),
  .clk(cpu_clk),
  .mem_addr(cpu_mem_addr),
  .rd_mem(cpu_rd_mem),
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
  .rst(cpu_rst),
  .clk(clk),
  .load(load_cdtimer),
  .data(wr_data),
  .counter(cdtimer_cnt),
  .timeout(cdtimer_to)
);

assign load_cdtimer = cpu_wr_mem & mem_addr === `ADDR_WIDTH'h002;

always @(posedge clk, posedge cpu_rst) begin
  if (cpu_rst)
    cdtimer_ie <= 1'b0;
  else if (cpu_wr_mem && mem_addr === `ADDR_WIDTH'h004)
    cdtimer_ie <= wr_data[1];
end

// MCU 内蔵周辺機能：UART
logic [7:0] uart_rx_byte, uart_tx_byte;
logic uart_rd, uart_rx_full, uart_wr, uart_tx_ready, uart_ie;
logic prog_recv, end_prog_recv;

uart_mux#(.CLOCK_HZ(CLOCK_HZ), .BAUD(UART_BAUD), .TIM_WIDTH(8)) uart_mux(
  .rst(rst),
  .clk(clk),
  .rx(uart_rx),
  .tx(uart_tx),
  .rx_data(uart_rx_byte),
  .tx_data(uart_tx_byte),
  .rd(uart_rd),
  .rx_full(uart_rx_full),
  .wr(uart_wr),
  .tx_ready(uart_tx_ready),
  .prog_recv(prog_recv),
  .end_prog_recv(end_prog_recv)
);

assign uart_rd = uart_rx_full;
assign uart_wr = cpu_wr_mem & mem_addr === `ADDR_WIDTH'h006;
assign uart_tx_byte = cpu_wr_data[7:0];
assign end_prog_recv = recv_data_v & recv_data === 16'h7fff;

always @(posedge clk, posedge rst) begin
  if (rst)
    uart_ie <= 1'b0;
  else if (cpu_wr_mem && mem_addr === `ADDR_WIDTH'h008)
    uart_ie <= wr_data[1];
end

// MCU 内蔵周辺機能：ADC
logic [7:0] adc_result;

adc#(.CLOCK_HZ(CLOCK_HZ)) adc(
  .rst(rst),
  .clk(clk),
  .clk125(clk125),
  .adc_cmp(adc_cmp),
  .adc_sh_ctl(adc_sh_ctl),
  .adc_dac_pwm(adc_dac_pwm),
  .adc_result(adc_result)
);

// MCU 内蔵周辺機能：ユーザーフラッシュ
always @(posedge clk, posedge cpu_rst) begin
  if (cpu_rst) begin
    uf_xadr <= 0;
    uf_yadr <= 0;
    {uf_nvstr, uf_prog, uf_erase, uf_se, uf_ye, uf_xe} <= 0;
    uf_din <= 0;
  end
  else if (cpu_wr_mem)
    case (mem_addr)
      `ADDR_WIDTH'h010: uf_xadr <= wr_data[8:0];
      `ADDR_WIDTH'h012: uf_yadr <= wr_data[5:0];
      `ADDR_WIDTH'h014: {uf_nvstr, uf_prog, uf_erase, uf_se, uf_ye, uf_xe} <= wr_data[5:0];
      `ADDR_WIDTH'h018: uf_din[15:0] <= wr_data;
      `ADDR_WIDTH'h01A: uf_din[31:16] <= wr_data;
      `ADDR_WIDTH'h01C: ; // cannot write to df_uout
      `ADDR_WIDTH'h01E: ; // cannot write to df_uout
    endcase
end

// MCU 内蔵周辺機能：SPI
logic spi_cs, spi_tx_start, spi_tx_ready;
logic [7:0] spi_rx_data;

assign spi_tx_start = cpu_wr_mem & mem_addr === `ADDR_WIDTH'h020;

spi#(.CLOCK_HZ(CLOCK_HZ), .BAUD(100_000)) spi(
  .rst(rst),
  .clk(clk),
  .sclk(spi_sclk),
  .mosi(spi_mosi),
  .miso(spi_miso),
  .tx_data(wr_data[7:0]),
  .rx_data(spi_rx_data),
  .tx_start(spi_tx_start),
  .tx_ready(spi_tx_ready)
);

always @(posedge rst, posedge clk) begin
  if (rst)
    spi_cs <= 1;
  else if (cpu_wr_mem & mem_addr === `ADDR_WIDTH'h022)
    spi_cs <= wr_data[1];
end

// MCU 内蔵周辺機能のメモリマップ
function [15:0] read_memreg(input [`ADDR_WIDTH-1:0] mem_addr);
  casex (mem_addr)
    `ADDR_WIDTH'h002: read_memreg = cdtimer_cnt;
    `ADDR_WIDTH'h004: read_memreg = {14'd0, cdtimer_ie, cdtimer_to};
    `ADDR_WIDTH'h006: read_memreg = {8'd0, recv_data[7:0]};
    `ADDR_WIDTH'h008: read_memreg = {13'd0, uart_tx_ready, uart_ie, uart_rx_ready};
    `ADDR_WIDTH'h00A: read_memreg = {8'd0, adc_result};
    `ADDR_WIDTH'h010: read_memreg = {7'd0, uf_xadr};
    `ADDR_WIDTH'h012: read_memreg = {10'd0, uf_yadr};
    `ADDR_WIDTH'h014: read_memreg = {10'd0, uf_nvstr, uf_prog, uf_erase, uf_se, uf_ye, uf_xe};
    `ADDR_WIDTH'h018: read_memreg = uf_din[15:0];
    `ADDR_WIDTH'h01A: read_memreg = uf_din[31:16];
    `ADDR_WIDTH'h01C: read_memreg = uf_dout[15:0];
    `ADDR_WIDTH'h01E: read_memreg = uf_dout[31:16];
    `ADDR_WIDTH'h020: read_memreg = {8'd0, spi_rx_data};
    `ADDR_WIDTH'h022: read_memreg = {14'd0, spi_cs, spi_tx_ready};
    default:          read_memreg = CLK_DIV >= 2 ? rd_data_d : rd_data;
  endcase
endfunction

// 信号結線
assign wr_mem   = ~recv_compl | cpu_wr_mem;
assign byt      = recv_compl ? cpu_byt : 1'b0;
assign mem_addr = recv_compl ? cpu_mem_addr : recv_addr;
assign wr_data  = recv_compl ? cpu_wr_data : recv_data;
assign cpu_rd_data = read_memreg(mem_addr_d);
assign cpu_irq  = (cdtimer_to & cdtimer_ie) | (uart_rx_ready & uart_ie);

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
  if (rst | recv_compl)
    recv_phase <= 1'b0;
  else if (uart_rx_full)
    recv_phase <= ~recv_phase;
end

// recv_data は UART から受信した直近 2 バイトを記憶する
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_data <= 10'd0;
  else if (uart_rx_full)
    recv_data <= {recv_data[7:0], uart_rx_byte};
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
    recv_addr <= `ADDR_WIDTH'h4000;
  else if (recv_data_v)
    recv_addr <= recv_addr + `ADDR_WIDTH'd2;
end

always @(posedge rst, posedge clk) begin
  if (rst)
    recv_compl <= 1'b1;
  else if (end_prog_recv)
    recv_compl <= 1'b1;
  else if (prog_recv)
    recv_compl <= 1'b0;
end

always @(posedge cpu_rst, posedge clk) begin
  if (cpu_rst)
    uart_rx_ready <= 1'b0;
  else if (uart_rx_full)
    uart_rx_ready <= 1'b1;
  else if (cpu_rd_mem & mem_addr_d === `ADDR_WIDTH'h006)
    uart_rx_ready <= 1'b0;
  else if (cpu_wr_mem & mem_addr === `ADDR_WIDTH'h008)
    uart_rx_ready <= cpu_wr_data[0];
end

endmodule
