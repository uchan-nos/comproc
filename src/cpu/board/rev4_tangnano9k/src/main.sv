`include "../../../common.sv"

module main(
  input sys_clk,
  input rst_n_raw,
  input uart_rx,
  output uart_tx,
  output [7:0] led_col,
  output [7:3] led_row,
  output tf_cs, tf_mosi, tf_sclk,
  input  tf_miso,
  output lcd_e,
  output lcd_rw,
  output lcd_rs,
  output [7:4] lcd_db,
  inout [7:0] gpio, // GPIO (HDMI pins)
  input  adc_cmp,     // ADC のコンパレータ出力
  output adc_sh_ctl,  // ADC のサンプル&ホールドスイッチ制御
  output adc_dac_pwm, // ADC の DAC PWM 信号
  output [5:0] onboard_led
);

parameter PERIOD = 16'd27000;
parameter GAP_ON = 16'd100;
parameter GAP_OFF = 16'd2000;

// logic 定義
logic rst_n;
logic [15:0] counter;
logic [2:0] row_index;

logic dmem_wen, dmem_byt;
logic [`ADDR_WIDTH-1:0] dmem_addr, dmem_addr_d;
logic [15:0] dmem_rdata, dmem_wdata;

logic [15:0] dmem_rdata_raw;

logic [7:0] cpu_out;
logic [17:0] cpu_uart_recv_data;
logic [`ADDR_WIDTH-1:0] img_pmem_size;

logic [7:0] io_led, io_lcd, io_gpio;
logic clk125;

// 継続代入
assign led_row = 5'h1f ^ (led_on(counter) << row_index);
assign led_col = led_pattern(row_index);

assign lcd_e  = io_lcd[0];
assign lcd_rw = io_lcd[1];
assign lcd_rs = io_lcd[2];
assign lcd_db = io_lcd[7:4];

assign dmem_rdata = read_mem_or_io(
  dmem_addr_d, dmem_rdata_raw, io_led, io_lcd, io_gpio);

assign gpio = io_gpio;

assign onboard_led = 6'b101010;

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

// LED の各行に情報を表示
function [7:0] led_pattern(input [3:0] row_index);
  case (row_index)
    3'd0:    led_pattern = 8'b10000000;
    3'd1:    led_pattern = 8'b01000000;
    3'd2:    led_pattern = 8'b00100000;
    3'd3:    led_pattern = 8'b00010000;
    3'd4:    led_pattern = io_led;
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
    row_index <= 3'd0;
  else if (counter == 0)
    if (row_index < 3'd4)
      row_index <= row_index + 3'd1;
    else
      row_index <= 3'd0;
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
  else if (dmem_wen && dmem_addr == `ADDR_WIDTH'h080)
    if (dmem_byt)
      io_led <= dmem_wdata[7:0];
    else
      {io_lcd, io_led} <= dmem_wdata;
  else if (dmem_wen && dmem_addr == `ADDR_WIDTH'h081)
    io_lcd <= dmem_wdata[15:8];
  else if (dmem_wen && dmem_addr == `ADDR_WIDTH'h082)
    if (dmem_byt)
      io_gpio <= dmem_wdata[7:0];
    else
      io_gpio <= dmem_wdata[7:0];
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    dmem_addr_d <= `ADDR_WIDTH'd0;
  else
    dmem_addr_d <= dmem_addr;
end

// 周辺機能用高速クロック
Gowin_OSC internal_osc_125mhz(
  .oscout(clk125) // 125MHz
);

// MCU 内蔵周辺機能：ユーザーフラッシュ
logic [8:0] uf_xadr;
logic [5:0] uf_yadr;
logic uf_xe, uf_ye, uf_se, uf_erase, uf_prog, uf_nvstr;
logic [31:0] uf_din, uf_dout;
FLASH608K flash608k_instance(
  .XADR(uf_xadr),
  .YADR(uf_yadr),
  .XE(uf_xe),
  .YE(uf_ye),
  .SE(uf_se),
  .ERASE(uf_erase),
  .PROG(uf_prog),
  .NVSTR(uf_nvstr),
  .DIN(uf_din),
  .DOUT(uf_dout)
);

// 自作 CPU を接続する
mcu mcu(
  .rst(~rst_n),
  .clk(sys_clk),
  .uart_rx(uart_rx),
  .uart_tx(uart_tx),
  .dmem_addr(dmem_addr),
  .dmem_wen(dmem_wen),
  .dmem_byt(dmem_byt),
  .dmem_rdata(dmem_rdata),
  .dmem_wdata(dmem_wdata),
  .uart_recv_data(cpu_uart_recv_data),
  .img_pmem_size(img_pmem_size),
  .clk125(clk125),
  .adc_cmp(adc_cmp),
  .adc_sh_ctl(adc_sh_ctl),
  .adc_dac_pwm(adc_dac_pwm),
  .uf_xadr(uf_xadr),
  .uf_yadr(uf_yadr),
  .uf_xe(uf_xe),
  .uf_ye(uf_ye),
  .uf_se(uf_se),
  .uf_erase(uf_erase),
  .uf_prog(uf_prog),
  .uf_nvstr(uf_nvstr),
  .uf_din(uf_din),
  .uf_dout(uf_dout),
  .spi_cs(tf_cs),
  .spi_sclk(tf_sclk),
  .spi_mosi(tf_mosi),
  .spi_miso(tf_miso)
);

// メモリ
dmem dmem(
  .rst(~rst_n),
  .clk(sys_clk),
  .addr(dmem_addr),
  .wen(dmem_wen),
  .byt(dmem_byt),
  .data_in(dmem_wdata),
  .data_out(dmem_rdata_raw)
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
