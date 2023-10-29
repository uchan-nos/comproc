module uart_mux_tb();

logic rst, clk;
logic rx, tx, rd, rx_full, wr, tx_ready;
logic [7:0] rx_data, tx_data;

integer i;

initial begin
  rst <= 1;
  clk <= 1;
  rx <= 1;
  rd <= 0;
  wr <= 0;
  $monitor("%7t: rst=%d rx=%d data=%x full=%d rd=%d",
           $time, rst, rx, rx_data, rx_full, rd,
           " tx=%d data=%x ready=%d wr=%d",
           tx, tx_data, tx_ready, wr
           );

  #13 rst <= 0;
  @(posedge clk);

  // 55 AA を受け取ったらプログラム転送モードになり、
  // それ以外では受信が継続することを確認

  // 55 以外はすぐに受信
  recv_byte(8'h61);
  #50;
  if (rx_full !== 1) $error("rx_full must be 1");
  if (rx_data !== 8'h61) $error("rx_data must be 61: %x", rx_data);
  read();
  if (rx_full !== 0) $error("rx_full must be 0");

  // 55 は 20ms 後に受信
  recv_byte(8'h55);
  #50;
  if (rx_full !== 0) $error("rx_full must be 0");
  if (rx_data !== 8'h61) $error("rx_data must be 61: %x", rx_data);

  #200000; // 17.4ms 経過。まだまだ。
  $display("17.4ms from 55 received");
  if (rx_full !== 0) $error("rx_full must be 0");
  if (rx_data !== 8'h61) $error("rx_data must be 61: %x", rx_data);

  #40000; // 3.5ms 経過。合計で 20ms 以上！
  $display("20.8ms from 55 received");
  if (rx_full !== 1) $error("rx_full must be 1");
  if (rx_data !== 8'h55) $error("rx_data must be 55: %x", rx_data);
  read();
  if (rx_full !== 0) $error("rx_full must be 0");

  // 55 の直後に他の値が来たら、その時点で受信
  recv_byte(8'h55);
  recv_byte(8'h42);
  #50;
  if (rx_full !== 1) $error("rx_full must be 1");
  if (rx_data !== 8'h55) $error("rx_data must be 55: %x", rx_data);
  read();
  if (rx_full !== 1) $error("rx_full must be 1");

  @(posedge clk);
  if (rx_full !== 1) $error("rx_full must be 1");
  if (rx_data !== 8'h42) $error("rx_data must be 42: %x", rx_data);
  read();
  if (rx_full !== 0) $error("rx_full must be 0");

  // 55 受信後 0.2ms～20ms の間に AA が来たら、プログラム転送モードへ

  $finish;
end

always #5 begin
  clk <= ~clk;
end

task recv_byte(input [7:0] value);
begin
  rx <= 0; // START
  for (i = 0; i < 8; i++) begin
    #100 rx <= value[i];
  end
  #100 rx <= 1; // STOP
  #100;
  $display("received %x", value);
end
endtask

task read;
begin
  rd <= 1;
  @(posedge clk);
  #1 rd <= 0;
end
endtask

uart_mux#(.CLOCK_HZ(1152000), .BAUD(115200)) uart(.*);

endmodule
