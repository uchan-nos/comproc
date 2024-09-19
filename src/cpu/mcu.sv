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
  output [15:0] stack0, stack1,
  output [17:0] insn,
  output [5:0] alu_sel, // デバッグ出力
  output load_insn,
  output [15:0] ip,
  output [1:0] phase,
  output load_ip,
  output [17:0] uart_recv_data,
  output [`ADDR_WIDTH-1:0] img_pmem_size,
  input  clk125,
  input  adc_cmp,     // ADC のコンパレータ出力
  output adc_sh_ctl,  // ADC のサンプル&ホールドスイッチ制御
  output adc_dac_pwm, // ADC の DAC PWM 信号
  output logic [8:0] uf_xadr,
  output logic [5:0] uf_yadr,
  output logic uf_xe, uf_ye, uf_se, uf_erase, uf_prog, uf_nvstr,
  output logic [31:0] uf_din,
  input  [31:0] uf_dout,
  output logic spi_cs,
  output spi_sclk, spi_mosi,
  input  spi_miso
);

// CPU コア
logic [`ADDR_WIDTH-1:0] cpu_mem_addr, mem_addr_d;
logic [15:0] cpu_rd_data, cpu_wr_data;
logic [17:0] cpu_rd_pmem, wr_pmem;
logic cpu_rd_mem, cpu_wr_mem, cpu_byt, cpu_irq;
logic cpu_rst, we_pmem;

logic [17:0] recv_data;
logic [`ADDR_WIDTH-1:0] img_recv_addr, pmem_size, dmem_size;

assign uart_recv_data = recv_data;
assign img_pmem_size = pmem_size;

typedef enum logic [2:0] {
  IMG_RECV_WAIT, // メモリイメージ受信開始（55 AA）を待っている
  IMG_RECV_META, // メタデータ（データサイズなど）受信中
  IMG_RECV_PMEM, // pmem 受信中
  IMG_RECV_DMEM, // dmem 受信中
  IMG_RECV_FIN   // 終了処理
} img_recv_state_t;
img_recv_state_t img_recv_state;

// 0: 最上位バイトを待っている
// 2: 最下位バイトを待っている
logic [1:0] recv_byte_phase;

logic recv_data_v, recv_compl, uart_rx_ready;

//localparam CLK_DIV = 27_000_000 << 1;
//localparam CLK_DIV = 27_000_000 >> 1;
//localparam CLK_DIV = 27_000_000;
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
  //.pmem_addr(cpu_pmem_addr),
  .rd_mem(cpu_rd_mem),
  .wr_mem(cpu_wr_mem),
  .byt(cpu_byt),
  .rd_data(cpu_rd_data),
  .wr_data(cpu_wr_data),
  .rd_pmem(cpu_rd_pmem),
  .stack0(stack0),
  .stack1(stack1),
  .insn(insn),
  .load_insn(load_insn),
  .alu_sel(alu_sel),
  .ip(ip),
  .phase(phase),
  .load_ip(load_ip),
  .irq(cpu_irq)
);

// プログラムメモリ
pmem pmem(
  .rst(rst),
  .clk(clk),
  .addr(mem_addr),
  .wr(we_pmem),
  .wr_data(wr_pmem),
  .rd_data(cpu_rd_pmem)
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
logic img_recv, prog_recv;

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
  .img_recv(img_recv),
  .end_img_recv(img_recv_state == IMG_RECV_FIN)
);

assign uart_rd = uart_rx_full;
assign uart_wr = cpu_wr_mem & mem_addr === `ADDR_WIDTH'h006;
assign uart_tx_byte = cpu_wr_data[7:0];

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
logic spi_tx_start, spi_tx_ready;
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
function [15:0] read_memreg(input [`ADDR_WIDTH-1:0] mem_addr, input [15:0] rd_data);
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
assign wr_mem   = (img_recv_state == IMG_RECV_WAIT & cpu_wr_mem)
                | (img_recv_state == IMG_RECV_DMEM & img_recv_addr < dmem_size);
assign byt      = cpu_byt;
assign mem_addr = recv_compl ? cpu_mem_addr : img_recv_addr;
assign wr_data  = (~recv_compl & ~prog_recv) ? recv_data[15:0] : cpu_wr_data;
assign we_pmem  = img_recv_state == IMG_RECV_PMEM & img_recv_addr < pmem_size;
assign wr_pmem  = recv_data;
assign cpu_rd_data = read_memreg(mem_addr_d, rd_data);
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

always @(posedge rst, posedge clk) begin
  if (rst)
    img_recv_state <= IMG_RECV_WAIT;
  else if (img_recv_state == IMG_RECV_WAIT & img_recv)
    img_recv_state <= IMG_RECV_META;
  else if (img_recv_state == IMG_RECV_META & img_recv_addr == `ADDR_WIDTH'd2)
    img_recv_state <= IMG_RECV_PMEM;
  else if (img_recv_state == IMG_RECV_PMEM & img_recv_addr == pmem_size)
    img_recv_state <= IMG_RECV_DMEM;
  else if (img_recv_state == IMG_RECV_DMEM & img_recv_addr == dmem_size)
    img_recv_state <= IMG_RECV_FIN;
  else if (img_recv_state == IMG_RECV_FIN)
    img_recv_state <= IMG_RECV_WAIT;
end

always @(posedge rst, posedge clk) begin
  if (rst | recv_compl) begin
    pmem_size <= `ADDR_WIDTH'd0;
    dmem_size <= `ADDR_WIDTH'd0;
  end
  else if (recv_data_v && img_recv_state == IMG_RECV_META)
    if (img_recv_addr == `ADDR_WIDTH'd0)
      pmem_size <= recv_data[`ADDR_WIDTH-1:0];
    else if (img_recv_addr == `ADDR_WIDTH'd1)
      dmem_size <= recv_data[`ADDR_WIDTH-1:0];
end

always @(posedge rst, posedge clk) begin
  if (rst | recv_compl)
    recv_byte_phase <= 2'd0;
  else if (recv_data_v)
    recv_byte_phase <= 2'd0;
  else if (uart_rx_full)
    recv_byte_phase <= recv_byte_phase + 2'd1;
end

// recv_data は UART から受信した直近 18 ビットを記憶する
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_data <= 18'd0;
  else if (uart_rx_full)
    recv_data <= {recv_data[9:0], uart_rx_byte};
end

// recv_data_v は命令の受信が完了したら 1 になる
always @(posedge rst, posedge clk) begin
  if (rst | img_recv_state == IMG_RECV_WAIT)
    recv_data_v <= 1'b0;
  else if (img_recv_state == IMG_RECV_META)
    recv_data_v <= uart_rx_full & recv_byte_phase == 2'd1;
  else if (img_recv_state == IMG_RECV_PMEM)
    recv_data_v <= uart_rx_full & recv_byte_phase == 2'd2;
  else if (img_recv_state == IMG_RECV_DMEM)
    recv_data_v <= uart_rx_full & recv_byte_phase == 2'd1;
end

// img_recv_addr は命令の受信が完了するたびにインクリメントされる
always @(posedge rst, posedge clk) begin
  if (rst | img_recv_state == IMG_RECV_WAIT)
    img_recv_addr <= `ADDR_WIDTH'd0;
  else if ((img_recv_state == IMG_RECV_META && img_recv_addr == `ADDR_WIDTH'd2) ||
           (img_recv_state == IMG_RECV_PMEM && img_recv_addr == pmem_size) ||
           (img_recv_state == IMG_RECV_DMEM && img_recv_addr == dmem_size))
    img_recv_addr <= `ADDR_WIDTH'd0;
  else if (recv_data_v)
    img_recv_addr <= img_recv_addr + `ADDR_WIDTH'd1;
end

always @(posedge rst, posedge clk) begin
  if (rst)
    recv_compl <= 1'b1;
  else if (img_recv_state == IMG_RECV_FIN)
    recv_compl <= 1'b1;
  else if (img_recv)
    recv_compl <= 1'b0;
end

always @(posedge rst, posedge clk) begin
  if (rst | recv_compl)
    prog_recv <= 1'b1;
  else if (recv_data_v & recv_data == 18'h1fffe)
    prog_recv <= 1'b0;
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
