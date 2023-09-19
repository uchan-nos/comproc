`include "common.sv"

module mcu#(
  parameter CLOCK_HZ = 27_000_000
) (
  input rst, clk, uart_rx,
  output uart_tx, [`ADDR_WIDTH-1:0] mem_addr,
  output wr_mem, byt,
  input  [15:0] rd_data, // メモリ読み込みデータバス
  output [15:0] wr_data, // メモリ書き込みデータバス
  output [15:0] stack0, [15:0] stack1, [5:0] alu_sel // デバッグ出力
);

logic [`ADDR_WIDTH-1:0] cpu_mem_addr;
logic [15:0] cpu_rd_data, cpu_wr_data;
logic cpu_wr_mem, cpu_byt;
logic [7:0] uart_rx_data, uart_tx_data;
logic uart_rd, uart_rx_full, uart_wr, uart_tx_ready;

logic [15:0] recv_data;
logic [`ADDR_WIDTH-1:0] recv_addr;
logic recv_phase, recv_data_v, recv_compl;

//localparam CLK_DIV = 27_000_000 / 2;
localparam CLK_DIV = 1;
logic [24:0] clk_div_cnt;
logic clk_div;

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

cpu#(.CLOCK_HZ(CLOCK_HZ)) cpu(
  .rst(rst),
  .clk(CLK_DIV >= 2 ? clk_div : clk),
  .mem_addr(cpu_mem_addr),
  .wr_mem(cpu_wr_mem),
  .byt(cpu_byt),
  .rd_data(cpu_rd_data),
  .wr_data(cpu_wr_data),
  .stack0(stack0),
  .stack1(stack1),
  .alu_sel(alu_sel)
);

uart#(.CLOCK_HZ(CLOCK_HZ), .BAUD(115200), .TIM_WIDTH(8)) uart(
  .rst(rst),
  .clk(clk),
  .rx(uart_rx),
  .tx(uart_tx),
  .rx_data(uart_rx_data),
  .tx_data(uart_tx_data),
  .rd(uart_rd),
  .rx_full(uart_rx_full),
  .wr(uart_wr),
  .tx_ready(uart_tx_ready)
);

assign wr_mem   = ~recv_compl | cpu_wr_mem;
assign byt      = recv_compl ? cpu_byt : 1'b0;
assign mem_addr = recv_compl ? cpu_mem_addr : recv_addr;
assign wr_data  = recv_compl ? cpu_wr_data : recv_data;

assign uart_rd = uart_rx_full;

// recv_phase は上位バイトを待っているとき 0、下位バイトを待っているとき 1
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_phase <= 1'b0;
  else if (uart_rx_full)
    recv_phase <= ~recv_phase;
end

// recv_data は UART から受信した直近 2 バイトを記憶する
always @(posedge rst, posedge clk) begin
  if (rst)
    recv_data <= 10'd0;
  else if (uart_rx_full)
    recv_data <= {recv_data[7:0], uart_rx_data};
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
    recv_addr <= `ADDR_WIDTH'h300;
  else if (recv_data_v)
    recv_addr <= recv_addr + `ADDR_WIDTH'd2;
end

always @(posedge rst, posedge clk) begin
  if (rst)
    recv_compl <= 1'b0;
  else if (recv_data == 16'h7fff)
    recv_compl <= 1'b1;
  else if (recv_phase == 1 && recv_data[7:2] != 6'b0111_11)
    recv_compl <= 1'b0;
end

endmodule
