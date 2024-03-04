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
  output [7:4] lcd_db,
  inout [7:0] gpio, // GPIO (HDMI pins)
  input  adc_cmp,     // ADC のコンパレータ出力
  output adc_sh_ctl,  // ADC のサンプル&ホールドスイッチ制御
  output adc_dac_pwm  // ADC の DAC PWM 信号
);

parameter PERIOD = 16'd27000;
parameter GAP_ON = 16'd100;
parameter GAP_OFF = 16'd2000;

// logic 定義
logic rst_n;
logic [15:0] counter;
logic [3:0] row_index;

logic [`ADDR_WIDTH-1:0] recv_addr;
logic recv_phase, recv_compl;

logic mem_wr, mem_byt;
logic [`ADDR_WIDTH-1:0] mem_addr, mem_addr_d;
logic [15:0] rd_data, wr_data;

logic [15:0] bram_rd_data;

logic [7:0] cpu_out;
logic [15:0] cpu_stack0, cpu_stack1, cpu_insn;
logic [5:0] cpu_alu_sel;
logic cpu_load_insn;

logic [7:0] io_led, io_lcd, io_gpio;

// 継続代入
assign led_row = 9'h1ff ^ (led_on(counter) << row_index);
assign led_col = led_pattern(row_index);

assign lcd_e  = io_lcd[0];
assign lcd_rw = io_lcd[1];
assign lcd_rs = io_lcd[2];
assign lcd_db = io_lcd[7:4];

//assign mem_wr = ~recv_compl | cpu_mem_wr;
//assign mem_byt = recv_compl ? cpu_mem_byt : 1'b0;
//assign mem_addr = recv_compl ? cpu_mem_addr : recv_addr;
assign rd_data = read_mem_or_io(
  mem_addr_d, bram_rd_data, io_led, io_lcd, io_gpio);

assign gpio = io_gpio;

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

// LED の各行に情報を表示
function [7:0] led_pattern(input [3:0] row_index);
  case (row_index)
    4'd0:    led_pattern = cpu_insn[15:8];
    4'd1:    led_pattern = cpu_insn[7:0];
    //4'd0:    led_pattern = wr_data[15:8];
    //4'd1:    led_pattern = wr_data[7:0];
    4'd2:    led_pattern = cpu_stack0[15:8];
    4'd3:    led_pattern = cpu_stack0[7:0];
    4'd4:    led_pattern = cpu_stack1[15:8];
    4'd5:    led_pattern = cpu_stack1[7:0];
    4'd6:    led_pattern = {2'd0, cpu_alu_sel};
    4'd7:    led_pattern = io_led;
    //4'd6:    led_pattern = {cpu_load_insn, 3'd0, mem_addr[11:8]};
    //4'd7:    led_pattern = mem_addr[7:0];
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
  if (!rst_n) begin
    io_led <= 0;
    io_lcd <= 0;
    io_gpio <= 0;
  end
  else if (mem_wr && mem_addr == `ADDR_WIDTH'h080)
    if (mem_byt)
      io_led <= wr_data[7:0];
    else
      {io_lcd, io_led} <= wr_data;
  else if (mem_wr && mem_addr == `ADDR_WIDTH'h081)
    io_lcd <= wr_data[15:8];
  else if (mem_wr && mem_addr == `ADDR_WIDTH'h082)
    if (mem_byt)
      io_gpio <= wr_data[7:0];
    else
      io_gpio <= wr_data[7:0];
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    mem_addr_d <= `ADDR_WIDTH'd0;
  else
    mem_addr_d <= mem_addr;
end

// 自作 CPU を接続する
mcu mcu(
  .rst(~rst_n),
  .clk(sys_clk),
  .uart_rx(uart_rx),
  .uart_tx(uart_tx),
  .mem_addr(mem_addr),
  .wr_mem(mem_wr),
  .byt(mem_byt),
  .rd_data(rd_data),
  .wr_data(wr_data),
  .stack0(cpu_stack0),
  .stack1(cpu_stack1),
  .insn(cpu_insn),
  .load_insn(cpu_load_insn),
  .alu_sel(cpu_alu_sel),
  .adc_cmp(adc_cmp),
  .adc_sh_ctl(adc_sh_ctl),
  .adc_dac_pwm(adc_dac_pwm)
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

function [15:0] read_mem_or_io(
  input [`ADDR_WIDTH-1:0] addr, [15:0] mem,
  [7:0] io_led, io_lcd, io_gpio
);
begin
  casex (addr)
    `ADDR_WIDTH'b1000_000x: read_mem_or_io = {io_lcd, io_led};
    `ADDR_WIDTH'b1000_001x: read_mem_or_io = {8'd0, io_gpio};
    `ADDR_WIDTH'b1xxx_xxxx: read_mem_or_io = 16'd0;
    default:                read_mem_or_io = mem;
  endcase
end
endfunction

endmodule
