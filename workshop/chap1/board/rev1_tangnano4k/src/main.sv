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

// 継続代入
assign led_row = 9'b000000001;

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

always @(posedge sys_clk) begin
  if (!rst_n)
    led_col <= 8'b00000000;
  else
    led_col <= 8'b10101010;
end

endmodule
