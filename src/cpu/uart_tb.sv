module uart_tb();

logic rst, clk;
logic rx, tx, rd, rx_full, wr, tx_ready;
logic [7:0] rx_data, tx_data;

initial begin
  rst <= 1;
  clk <= 1;
  rx <= 1;
  wr <= 0;
  $monitor("%5t: rst=%d rx=%d rxdat=%x rx_full=%d rxtim_half=%d",
           $time, rst, rx, rx_data, rx_full, uart.rxtim_half,
           " tx=%d txdat=%x tx_ready=%d txtim_full=%d",
           tx, tx_data, tx_ready, uart.txtim_full
           );

  #13
    rst <= 0;

  repeat(2) @(posedge clk);
    rx <= 0; // START
  if (rx_full !== 0) $error("rx_full must be 0");

  #100 rx <= 1; // LSB
  #100 rx <= 0;
  #100 rx <= 1;
  #100 rx <= 0;
  #100 rx <= 0;
  #100 rx <= 0;
  #100 rx <= 1;
  if (rx_full !== 0) $error("rx_full must be 0");
  #100 rx <= 1; // MSB

  #100 rx <= 1; // STOP
  #200;

  if (rx_full !== 1) $error("rx_full must be 1");
  if (rx_data !== 8'hc5) $error("rx_data must be c5: %x", rx_data);

  @(posedge clk);
  rd <= 1;
  @(posedge clk);
  rd <= 0;

  #1;
  if (rx_full !== 0) $error("rx_full must be 0");

  @(posedge clk);
  tx_data <= 8'h49;
  wr <= 1;
  if (tx !== 1) $error("tx must be 1");
  if (tx_ready !== 1) $error("tx_ready must be 1");

  @(posedge clk) wr <= 0;
  if (tx_ready !== 0) $error("tx_ready must be 0");

  repeat(2) @(posedge clk);
  if (tx !== 0) $error("tx must be 0 (start bit)");

  repeat(10) @(posedge clk);
  if (tx !== 1) $error("tx must be 1 (LSB)");

  repeat(10) @(posedge clk);
  if (tx !== 0) $error("tx must be 0 (bit 1)");

  repeat(60) @(posedge clk);
  if (tx !== 0) $error("tx must be 0 (MSB)");

  repeat(10) @(posedge clk);
  if (tx !== 1) $error("tx must be 0 (stop bit)");
  if (tx_ready !== 0) $error("tx_ready must be 0");

  repeat(10) @(posedge clk);
  if (tx_ready !== 1) $error("tx_ready must be 1");

  repeat(200) @(posedge clk);
  $finish;
end

always #5 begin
  clk <= ~clk;
end

uart#(.CLK(100), .BAUD(10)) uart(.*);

endmodule
