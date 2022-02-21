module main(
  input sys_clk,
  input rst_n_raw,
  input uart_rx,
  output uart_tx,
  output [7:0] led_col,
  output [8:0] led_row
);

parameter PERIOD = 16'd27000;
parameter GAP = 16'd500;

// logic 定義
logic rst_n;
logic [15:0] counter;
logic [2:0] row_index;
logic [7:0] uart_rx_data, uart_tx_data;
logic uart_tx_en, uart_rx_data_wr;

// 継続代入
assign led_row = led_on(counter) << row_index;
assign led_col = led_pattern(row_index);

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

// row_index == 0 のときだけ点灯させる
function [7:0] led_pattern(input [2:0] row_index);
  case (row_index)
    3'd0:    led_pattern = 8'b10101010;
    3'd1:    led_pattern = uart_rx_data;
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
    row_index <= row_index + 3'd1;
end

// 隣接する行が光らないように制御する
function led_on(input [15:0] counter);
  led_on = (GAP <= counter) && (counter < PERIOD - GAP);
endfunction

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    uart_tx_data <= 8'd0;
  else if (uart_rx_data_wr)
    uart_tx_data <= uart_rx_data;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    uart_tx_en <= 1'd0;
  else if (uart_rx_data_wr)
    uart_tx_en <= 1'd1;
  else
    uart_tx_en <= 1'd0;
end

uart uart(
  .*,
  .rx_data(uart_rx_data),
  .rx_data_wr(uart_rx_data_wr),
  .tx_data(uart_tx_data),
  .tx_en(uart_tx_en)
);

endmodule
