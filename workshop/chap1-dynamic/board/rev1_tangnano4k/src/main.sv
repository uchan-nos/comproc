module main(
  input sys_clk,
  input rst_n_raw,
  input uart_rx,
  output uart_tx,
  output logic [7:0] led_col,
  output [8:0] led_row
);

// logic 定義
logic rst_n;
logic [15:0] counter;
logic [2:0] row_index;

// 継続代入
assign led_row = 9'd1 << row_index;

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

// row_index == 0 のときだけ点灯させる
always @(posedge sys_clk) begin
  if (!rst_n)
    led_col <= 8'b00000000;
  else if (row_index == 0)
    led_col <= 8'b10101010;
  else
    led_col <= 8'b00000000;
end

// counter を 1ms で 1 周させる
always @(posedge sys_clk) begin
  if (!rst_n)
    counter <= 16'd0;
  else if (counter >= 16'd27000 - 1)
    counter <= 16'd0;
  else
    counter <= counter + 16'd1;
end

// counter が 1 周したら row_index を更新する
always @(posedge sys_clk) begin
  if (!rst_n)
    row_index <= 3'd0;
  else if (counter == 0)
    row_index <= row_index + 3'd1;
end

endmodule
