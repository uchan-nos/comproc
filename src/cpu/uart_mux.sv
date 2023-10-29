module uart_mux#(
  parameter CLOCK_HZ=27_000_000,
  parameter BAUD=9600,
  parameter DATA_BITS=8,
  parameter TIM_WIDTH=16
) (
  input  rst, clk,
  input  rx,      // UART RX signal
  output tx,      // UART TX signal
  output logic [DATA_BITS-1:0] rx_data,
  input  logic [DATA_BITS-1:0] tx_data,
  input  rd,      // read rx buffer
  output logic rx_full, // rx buffer full
  input  wr,      // write tx buffer
  output tx_ready // ready to transmit
);

logic [DATA_BITS-1:0] rx_buf, uart_rx_data;
logic uart_rx_full, rx_buf_full;
logic rx_buf_55, rd_rx_buf;

assign rx_buf_55 = (rx_buf === 8'h55);
assign rd_rx_buf = ~rx_full & (~rx_buf_55 | tim_timeout);

always @(posedge rst, posedge clk) begin
  if (rst) begin
    rx_buf <= 0;
    rx_buf_full <= 0;
  end
  else if (uart_rx_full) begin
    rx_buf <= uart_rx_data;
    rx_buf_full <= 1;
  end
  else if (rd_rx_buf)
    rx_buf_full <= 0;
end

always @(posedge rst, posedge clk) begin
  if (rst) begin
    rx_data <= 0;
    rx_full <= 0;
  end
  else if (rx_buf_full) begin
    if (rd_rx_buf) begin
      rx_data <= rx_buf;
      rx_full <= 1;
    end
  end
  else if (rd)
    rx_full <= 0;
end

localparam TIM_LOWER = CLOCK_HZ/5000; // 0.2ms
localparam TIM_UPPER = CLOCK_HZ/50; // 20ms

logic [19:0] tim;
logic tim_in_range; // タイマーが指定した範囲にあるとき 1
logic tim_timeout; // タイマーが指定した範囲を超えたとき 1

assign tim_timeout = TIM_UPPER < tim;
assign tim_in_range = (TIM_LOWER <= tim) & ~tim_timeout;

always @(posedge rst, posedge clk) begin
  if (rst | ~rx_buf_55)
    tim <= 0;
  else if (~tim_timeout)
    tim <= tim + 1;
end

uart#(
  .CLOCK_HZ(CLOCK_HZ),
  .BAUD(BAUD),
  .DATA_BITS(DATA_BITS),
  .TIM_WIDTH(TIM_WIDTH)
) uart(
  .rx_data(uart_rx_data),
  .rd(uart_rx_full),
  .rx_full(uart_rx_full),
  .*
);

endmodule
