module uart(
  input sys_clk,
  input rst_n,
  input uart_rx,
  output uart_tx,
  output logic [7:0] rx_data,
  output logic rx_data_wr,
  input [7:0] tx_data,
  input tx_en
);

// 定数
localparam REG_RBR = 3'd0;
localparam REG_LSR = 3'd5;

// logic 定義
logic [7:0] rdata, wdata;
logic [2:0] raddr;
logic rx_en, rx_rdy, rx_v;

// 継続代入
assign raddr = rx_rdy ? REG_RBR : REG_LSR;
assign rx_rdy = ~rx_v & rdata[0];
assign wdata = tx_data;

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    rx_en <= 1'd0;
  else
    rx_en <= ~rx_en;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    rx_v <= 1'd0;
  else if (~rx_en)
    rx_v <= rx_rdy;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    rx_data <= 8'd0;
  else if (rx_v & rx_en)
    rx_data <= rdata;
end

always @(posedge sys_clk, negedge rst_n) begin
  if (!rst_n)
    rx_data_wr <= 1'd0;
  else if (rx_v & rx_en)
    rx_data_wr <= 1'd1;
  else
    rx_data_wr <= 1'd0;
end

UART_MASTER_Top uart_master(
  .I_CLK(sys_clk),  //input I_CLK
  .I_RESETN(rst_n), //input I_RESETN
  .I_TX_EN(tx_en),  //input I_TX_EN
  .I_WADDR(3'd0),   //input [2:0] I_WADDR
  .I_WDATA(wdata),  //input [7:0] I_WDATA
  .I_RX_EN(rx_en),  //input I_RX_EN
  .I_RADDR(raddr),  //input [2:0] I_RADDR
  .O_RDATA(rdata),  //output [7:0] O_RDATA
  .SIN(uart_rx),    //input SIN
  .RxRDYn(),        //output RxRDYn
  .SOUT(uart_tx),   //output SOUT
  .TxRDYn(),        //output TxRDYn
  .DDIS(),          //output DDIS
  .INTR(),          //output INTR
  .DCDn(1'b1),      //input DCDn
  .CTSn(1'b1),      //input CTSn
  .DSRn(1'b1),      //input DSRn
  .RIn(1'b1),       //input RIn
  .DTRn(),          //output DTRn
  .RTSn()           //output RTSn
);

endmodule
