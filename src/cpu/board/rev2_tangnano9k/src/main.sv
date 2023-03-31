`include "../../../common.sv"

module main(
  input sys_clk,
  input rst_n_raw,
  input uart_rx,
  output uart_tx,
  output [7:0] led_col,
  output [8:0] led_row,
  output lcd_e,
  output lcd_rw,
  output lcd_rs,
  output [7:4] lcd_db
);

parameter PERIOD = 16'd27000;
parameter GAP_ON = 16'd100;
parameter GAP_OFF = 16'd2000;

// logic 定義
logic rst_n;
logic [15:0] counter;
logic [3:0] row_index;
logic [7:0] uart_rx_data, uart_tx_data;
logic uart_tx_en, uart_rx_data_wr;

logic [15:0] recv_data;
logic [`ADDR_WIDTH-1:0] recv_addr;
logic recv_phase, recv_data_v, recv_compl;

logic mem_wr, mem_byt;
logic [`ADDR_WIDTH-1:0] mem_addr;

logic [15:0] bram_rd_data, wr_data;

logic [7:0] cpu_out;
logic [`ADDR_WIDTH-1:0] cpu_mem_addr, cpu_mem_addr_d;
logic [15:0] cpu_rd_data, cpu_wr_data;
logic cpu_mem_wr, cpu_mem_byt;
logic [15:0] cpu_stack[0:15];
logic [15:0] uart_in;

logic [7:0] cpu_io_lcd;
logic [7:0] cpu_io_led;

// 継続代入
assign led_row = led_on(counter) << row_index;
assign led_col = led_pattern(row_index);

assign lcd_e  = cpu_io_lcd[0];
assign lcd_rw = cpu_io_lcd[1];
assign lcd_rs = cpu_io_lcd[2];
assign lcd_db = cpu_io_lcd;

// FF FF を受け取ったら機械語の受信完了と判断
//assign recv_compl = recv_data == 16'hffff;
assign mem_wr = ~recv_compl | cpu_mem_wr;
assign mem_byt = recv_compl ? cpu_mem_byt : 1'b0;
assign mem_addr = recv_compl ? cpu_mem_addr : recv_addr;
assign wr_data = recv_compl ? cpu_wr_data : recv_data;
assign cpu_rd_data = read_mem_or_reg(
  cpu_mem_addr_d, bram_rd_data, cpu_io_led, cpu_io_lcd, uart_in);

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

// LED の各行に情報を表示
function [7:0] led_pattern(input [3:0] row_index);
  case (row_index)
    4'd0:    led_pattern = wr_data[15:8];
    4'd1:    led_pattern = wr_data[7:0];
    4'd2:    led_pattern = cpu_stack[0][7:0];
    4'd3:    led_pattern = cpu_stack[1][7:0];
    4'd4:    led_pattern = cpu_stack[2][7:0];
    4'd5:    led_pattern = cpu_stack[3][7:0];
    4'd6:    led_pattern = cpu_stack[4][7:0];
    4'd7:    led_pattern = cpu_io_led;
    4'd8:    led_pattern = encode_7seg(mem_addr[4:0]);
    default: led_pattern = 8'b00000000;
  endcase
endfunction

// counter を 1ms で 1 周させる
always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    counter <= 16'd0;
  else if (counter >= PERIOD - 1)
    counter <= 16'd0;
  else
    counter <= counter + 16'd1;
end

// counter が 1 周したら row_index を更新する
always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    row_index <= 4'd0;
  else if (counter == 0)
    if (row_index < 4'd8)
      row_index <= row_index + 4'd1;
    else
      row_index <= 4'd0;
end

// 隣接する行が光らないように制御する
function led_on(input [15:0] counter);
  led_on = (GAP_ON <= counter) && (counter < PERIOD - GAP_OFF);
endfunction

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    uart_tx_data <= 8'd0;
  else if (cpu_mem_wr && (cpu_mem_addr & `ADDR_WIDTH'hffe) == `ADDR_WIDTH'h01c)
    {cpu_io_lcd, cpu_io_led} <= cpu_wr_data;
  else if (cpu_mem_wr && cpu_mem_addr == `ADDR_WIDTH'h01e)
    uart_tx_data <= cpu_wr_data[7:0];
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    uart_tx_en <= 1'd0;
  else if (cpu_mem_wr && cpu_mem_addr == `ADDR_WIDTH'h01e)
    uart_tx_en <= 1'd1;
  else
    uart_tx_en <= 1'd0;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    cpu_mem_addr_d <= `ADDR_WIDTH'd0;
  else
    cpu_mem_addr_d <= cpu_mem_addr;
end

uart uart(
  .*,
  .rx_data(uart_rx_data),
  .rx_data_wr(uart_rx_data_wr),
  .tx_data(uart_tx_data),
  .tx_en(uart_tx_en)
);

/* UART で受信したデータを BRAM に書き込む。

命令長は 16 ビットなので、BRAM も 16 ビット幅で読み書きする。
一方で UART は 8 ビットずつの送受信なので、recv_data に 2 バイト貯める。

信号タイミング図
https://rawgit.com/osamutake/tchart-coffee/master/bin/editor-offline.html

sys_clk      _~_~_~_~_~_~_~_~_~
rx_data_wr   ___~~______~~_____
rx_data      X?==X=H======X=L=====
recv_phase   _____~~~~~~~~_____
recv_data_v  _____________~~___
recv_addr    =N==============X=N+1=
recv_data    =?====X={?,H}======X={H,L}===
*/

// recv_phase は上位バイトを待っているとき 0、下位バイトを待っているとき 1
always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    recv_phase <= 1'b0;
  else if (uart_rx_data_wr)
    recv_phase <= ~recv_phase;
end

// recv_data は UART から受信した直近 2 バイトを記憶する
always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    recv_data <= 10'd0;
  else if (uart_rx_data_wr)
    recv_data <= {recv_data[7:0], uart_rx_data};
end

// recv_data_v は命令の受信が完了したら 1 になる
always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    recv_data_v <= 1'b0;
  else if (uart_rx_data_wr & recv_phase)
    recv_data_v <= 1'b1;
  else
    recv_data_v <= 1'b0;
end

// recv_addr は命令の受信が完了するたびにインクリメントされる
always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    recv_addr <= 10'h200;
  else if (recv_compl)
    recv_addr <= 10'h200;
  else if (recv_data_v)
    recv_addr <= recv_addr + 10'd2;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    recv_compl <= 1'b0;
  else if (recv_data == 16'hffff)
    recv_compl <= 1'b1;
  else if (recv_phase == 1 && recv_data[7:1] != 7'h7f)
    recv_compl <= 1'b0;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    uart_in <= 16'd0;
  else if (recv_data_v)
    uart_in <= recv_data;
end

// 自作 CPU を接続する
cpu cpu(
  .rst(~rst_n | ~recv_compl),
  .clk(sys_clk),
  .mem_addr(cpu_mem_addr),
  .mem_wr(cpu_mem_wr),
  .mem_byt(cpu_mem_byt),
  .rd_data(cpu_rd_data),
  .wr_data(cpu_wr_data),
  .stack(cpu_stack)
);

logic bram_rst, bram_clk, bram_wr_lo, bram_wr_hi;
logic [`ADDR_WIDTH-2:0] bram_addr_lo, bram_addr_hi;
logic [7:0] bram_wr_data_lo, bram_wr_data_hi;
logic [7:0] bram_rd_data_lo, bram_rd_data_hi;

// メモリ
mem mem(
  .rst(~rst_n),
  .clk(sys_clk),
  .addr(mem_addr),
  .wr(mem_wr),
  .byt(mem_byt),
  .wr_data(wr_data),
  .rd_data(bram_rd_data),

  .bram_rst(bram_rst),
  .bram_clk(bram_clk),
  .wr_lo(bram_wr_lo),
  .wr_hi(bram_wr_hi),
  .addr_lo(bram_addr_lo),
  .addr_hi(bram_addr_hi),
  .wr_data_lo(bram_wr_data_lo),
  .wr_data_hi(bram_wr_data_hi),
  .rd_data_lo(bram_rd_data_lo),
  .rd_data_hi(bram_rd_data_hi)
);

// プログラムとデータを格納する BRAM（偶数アドレス）
Gowin_SDPB mem_lo(
  .clka(bram_clk),    //input clka
  .cea(bram_wr_lo),   //input cea
  .reseta(bram_rst),  //input reseta
  .clkb(bram_clk),    //input clkb
  .ceb(1'b1),         //input ceb
  .resetb(bram_rst),  //input resetb
  .oce(1'b0),         //input oce
  .ada(bram_addr_lo), //input [10:0] ada
  .din(bram_wr_data_lo),  //input [7:0] din
  .adb(bram_addr_lo), //input [10:0] adb
  .dout(bram_rd_data_lo)  //output [7:0] dout
);

// プログラムとデータを格納する BRAM（奇数アドレス）
Gowin_SDPB mem_hi(
  .clka(bram_clk),    //input clka
  .cea(bram_wr_hi),   //input cea
  .reseta(bram_rst),  //input reseta
  .clkb(bram_clk),    //input clkb
  .ceb(1'b1),         //input ceb
  .resetb(bram_rst),  //input resetb
  .oce(1'b0),         //input oce
  .ada(bram_addr_hi), //input [10:0] ada
  .din(bram_wr_data_hi),  //input [7:0] din
  .adb(bram_addr_hi), //input [10:0] adb
  .dout(bram_rd_data_hi)  //output [7:0] dout
);

function [7:0] encode_7seg(input [4:0] n);
begin
  case (n[3:0])
    /* 7 segment LED
    *    7
    * 2|~~~|6
    *  |-1-|
    * 3|___|5  .0
    *    4
    */
    4'h0: encode_7seg = {7'b1111110, n[4]};
    4'h1: encode_7seg = {7'b0110000, n[4]};
    4'h2: encode_7seg = {7'b1101101, n[4]};
    4'h3: encode_7seg = {7'b1111001, n[4]};
    4'h4: encode_7seg = {7'b0110011, n[4]};
    4'h5: encode_7seg = {7'b1011011, n[4]};
    4'h6: encode_7seg = {7'b1011111, n[4]};
    4'h7: encode_7seg = {7'b1110010, n[4]};
    4'h8: encode_7seg = {7'b1111111, n[4]};
    4'h9: encode_7seg = {7'b1111011, n[4]};
    4'ha: encode_7seg = {7'b1110111, n[4]};
    4'hb: encode_7seg = {7'b0011111, n[4]};
    4'hc: encode_7seg = {7'b1001110, n[4]};
    4'hd: encode_7seg = {7'b0111101, n[4]};
    4'he: encode_7seg = {7'b1001111, n[4]};
    4'hf: encode_7seg = {7'b1000111, n[4]};
  endcase
end
endfunction

function [15:0] read_mem_or_reg(
  input [`ADDR_WIDTH-1:0] addr,
  input [15:0] mem,
  input [7:0] io_led,
  input [7:0] io_lcd,
  input [15:0] uart_in
);
begin
  casex (addr)
    `ADDR_WIDTH'b1_110x: read_mem_or_reg = {io_lcd, io_led};
    `ADDR_WIDTH'b1_111x: read_mem_or_reg = uart_in;
    `ADDR_WIDTH'b1_xxxx: read_mem_or_reg = 16'd0;
    default:             read_mem_or_reg = mem;
  endcase
end
endfunction

endmodule
