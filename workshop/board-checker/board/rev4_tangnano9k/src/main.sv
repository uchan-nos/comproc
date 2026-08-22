// CPUボード組み立て確認用の8 x 8 LEDマトリクス表示。
// この基板では行選択がアクティブLow、列データがアクティブHigh。
module main(
  input  logic       sys_clk,
  input  logic       rst_n_raw,
  input  logic       uart_rx,
  output wire        uart_tx,
  output wire [7:0]  led_col,
  output wire [8:0]  led_row
);

  // Tang Nano 9Kの発振器は27 MHz。各行を1 ms表示するため、
  // 8行を一巡する表示更新周波数は125 Hzとなる。
  logic [14:0] scan_counter;
  logic [2:0]  scan_row;
  logic [25:0] animation_div;
  logic [1:0]  square_ring;
  logic        square_ring_outward;

  // 行走査・デッドタイム設定
  localparam logic [14:0] ROW_PERIOD = 15'd27_000;
  localparam logic [14:0] ROW_GAP    = 15'd500;

  // 横・縦方向とも中央2画素の間（x=3.5、y=3.5）を中心とする
  // 四角い輪の番号を返す。
  function automatic [1:0] square_band(
    input logic [2:0] x,
    input logic [2:0] y
  );
    integer dx2;
    integer dy2;
    integer x2;
    integer y2;
    integer square_distance;
    begin
      x2 = x * 2;
      y2 = y * 2;
      dx2 = (x < 4) ? (7 - x2) : (x2 - 7);
      dy2 = (y < 4) ? (7 - y2) : (y2 - 7);
      square_distance = (dx2 > dy2) ? dx2 : dy2;

      // 最初の点灯は、画面中央の4画素だけにする。
      if ((x == 3 || x == 4) && (y == 3 || y == 4)) square_band = 0;
      else if (square_distance <= 4)                 square_band = 1;
      else if (square_distance <= 6)                 square_band = 2;
      else                                            square_band = 3;
    end
  endfunction

  // 既存チャプターと同様に、行の点灯期間だけを返す。
  function automatic logic led_on(input logic [14:0] counter);
    led_on = (ROW_GAP <= counter) && (counter < ROW_PERIOD - ROW_GAP);
  endfunction

  // 現在走査している行の列パターンを作る。
  function automatic [7:0] led_pattern(
    input logic [1:0] ring,
    input logic [2:0] row
  );
    integer column;
    begin
      led_pattern = '0;
      for (column = 0; column < 8; column = column + 1)
        led_pattern[column] = (ring == square_band(column[2:0], row));
    end
  endfunction

  // デッドタイム中は全行をアクティブHigh（消灯）にする。
  assign led_row = 9'h1ff ^ (led_on(scan_counter) ? (9'b000000001 << scan_row) : 9'd0);
  assign led_col = led_pattern(square_ring, scan_row);
  assign uart_tx = 1'b1;

  always_ff @(posedge sys_clk) begin
    if (!rst_n_raw) begin
      scan_counter    <= '0;
      scan_row        <= '0;
      animation_div   <= '0;
      square_ring     <= '0;
      square_ring_outward <= 1'b1;
    end else begin
      if (scan_counter == ROW_PERIOD - 1) begin
        scan_counter <= '0;
        if (scan_row == 3'd7) begin
          scan_row  <= '0;
        end else begin
          scan_row <= scan_row + 1'b1;
        end
      end else begin
        scan_counter <= scan_counter + 1'b1;
      end

      // 一定時間ごとに輪を外側へ進め、最外周で反転して内側へ戻す。
      if (animation_div == 26'd8_099_999) begin
        animation_div <= '0;
        if (square_ring == 2'd3) begin
          square_ring <= 2'd2;
          square_ring_outward <= 1'b0;
        end else if (square_ring == 2'd0) begin
          square_ring <= 2'd1;
          square_ring_outward <= 1'b1;
        end else if (square_ring_outward) begin
          square_ring <= square_ring + 1'b1;
        end else begin
          square_ring <= square_ring - 1'b1;
        end
      end else begin
        animation_div <= animation_div + 1'b1;
      end
    end
  end

endmodule
