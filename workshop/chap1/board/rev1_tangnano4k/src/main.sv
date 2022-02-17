module main(
  input sys_clk,
  input rst_n_raw,
  input uart_rx,
  output uart_tx,
  output [7:0] led_col,
  output [8:0] led_row
);

// logic 定義
logic rst_n;

// 継続代入
assign led_row = rst_n ? 9'b000000001 : 9'd0;
assign led_col = 8'b10101010;

always @(posedge sys_clk) begin
  rst_n <= rst_n_raw;
end

endmodule
