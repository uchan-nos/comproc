`include "common.sv"

// Keyboard Controller
module kbc(
  input  rst, clk,
  input  [7:0] key_col,
  output [7:0] key_row,
  output queue_len,   // キューにあるデータの数
  input  queue_ren,   // キュー読み出し信号
  output [7:0] queue  // キューの先頭要素
);

parameter KEYSCAN_PERIOD = 16'd27000;

logic [15:0] ks_cnt;      // キースキャン用タイマ
logic [2:0] ks_row_index; // キースキャンの行番号
logic [7:0] ks_bitmap[0:7]; // キー状態のビットマップ（押されていれば 1）
logic [3:0] ks_diff_pos;  // 前回と今回で差があったビット位置（0xf: 差が無い）

logic scancode_v;     // scancode に有効値が入っていれば 1
logic [7:0] scancode; // 最後に押された・離されたキーのスキャンコード

// ********
// 継続代入
// ********

// key_row はオープンドレイン出力。1 で Hi-Z、0 で 0V 出力となる。
assign key_row = 8'hff ^ (8'b1 << ks_row_index);
assign ks_diff_pos = count_leading_zeros(ks_bitmap[ks_row_index] ^ key_col);

assign queue_len = scancode_v;
assign queue = scancode;

// ****************
// その他のロジック
// ****************

// ks_cnt を 1ms で 1 周させる
always @(posedge rst, posedge clk) begin
  if (rst)
    ks_cnt <= 16'd0;
  else if (ks_cnt >= KEYSCAN_PERIOD - 1)
    ks_cnt <= 16'd0;
  else
    ks_cnt <= ks_cnt + 16'd1;
end

// ks_cnt が 1 周したら ks_row_index を更新する
always @(posedge rst, posedge clk) begin
  if (rst)
    ks_row_index <= 3'd0;
  else if (ks_cnt == 0)
    ks_row_index <= ks_row_index + 3'd1;
end

// ks_cnt の真ん中でキー状態を取得しレジスタへ書く
always @(posedge rst, posedge clk) begin
  if (rst) begin
    scancode_v = 1'b0;
    scancode = 8'd0;
  end
  else if (ks_cnt == KEYSCAN_PERIOD/2) begin
    ks_bitmap[ks_row_index] = key_col;
    if (ks_diff_pos != 4'hF) begin
      // 前回と今回でキー状態に差があるなら、そのキーを scancode へ記録
      scancode_v = 1'b1;
      scancode = keypos_to_scancode(ks_row_index, ks_diff_pos[2:0])
               | (key_col[ks_diff_pos] << 7);
      // key_col: 0=push, 1=release
    end
  end
  else if (queue_ren) begin
    scancode_v = 1'b0;
    scancode = 8'd0;
  end
end

function [3:0] count_leading_zeros(input [7:0] v);
  casex (v)
    8'b1xxxxxxx: return 3'h0;
    8'b01xxxxxx: return 3'h1;
    8'b001xxxxx: return 3'h2;
    8'b0001xxxx: return 3'h3;
    8'b00001xxx: return 3'h4;
    8'b000001xx: return 3'h5;
    8'b0000001x: return 3'h6;
    8'b00000001: return 3'h7;
    default:     return 4'hF;
  endcase
endfunction

function [6:0] keypos_to_scancode(input [2:0] row, input [2:0] col);
  case ({row, col})
    // row col    ASCII-code     key   ASCII-name (if different)
    6'b000_000: return 7'h10; // E/J    DLE
    6'b000_001: return 7'h31; // 1
    6'b000_010: return 7'h32; // 2
    6'b000_011: return 7'h33; // 3
    6'b000_100: return 7'h34; // 4
    6'b000_101: return 7'h35; // 5
    6'b000_110: return 7'h36; // 6
    6'b000_111: return 7'h37; // 7
    6'b001_000: return 7'h38; // 8
    6'b001_001: return 7'h39; // 9
    6'b001_010: return 7'h30; // 0
    6'b001_011: return 7'h2D; // -
    6'b001_100: return 7'h5E; // ^
    6'b001_101: return 7'h5C; // \ SW42
    6'b001_110: return 7'h08; // BS     BS
    6'b001_111: return 7'h15; // Kana   NAK
    6'b010_000: return 7'h09; // Tab    HT
    6'b010_001: return 7'h51; // Q
    6'b010_010: return 7'h57; // W
    6'b010_011: return 7'h45; // E
    6'b010_100: return 7'h52; // R
    6'b010_101: return 7'h54; // T
    6'b010_110: return 7'h59; // Y
    6'b010_111: return 7'h55; // U
    6'b011_000: return 7'h49; // I
    6'b011_001: return 7'h4F; // O
    6'b011_010: return 7'h50; // P
    6'b011_011: return 7'h40; // @
    6'b011_100: return 7'h5B; // [
    6'b011_101: return 7'h20; // Space
    6'b011_110: return 7'h0A; // Enter  LF
    6'b011_111: return 7'h13; // 変換   DC3
    6'b100_000: return 7'h0F; // Caps   SI
    6'b100_001: return 7'h41; // A
    6'b100_010: return 7'h53; // S
    6'b100_011: return 7'h44; // D
    6'b100_100: return 7'h46; // F
    6'b100_101: return 7'h47; // G
    6'b100_110: return 7'h48; // H
    6'b100_111: return 7'h4A; // J
    6'b101_000: return 7'h4B; // K
    6'b101_001: return 7'h4C; // L
    6'b101_010: return 7'h3B; // ;
    6'b101_011: return 7'h3A; // :
    6'b101_100: return 7'h5D; // ]
    6'b101_101: return 7'h12; // Alt    DC2
    6'b101_110: return 7'h14; // 無変換 DC4
    6'b101_111: return 7'h1C; // Up     FS
    6'b110_000: return 7'h0E; // Shift  SO
    6'b110_001: return 7'h11; // Ctrl   DC1
    6'b110_010: return 7'h5A; // Z
    6'b110_011: return 7'h58; // X
    6'b110_100: return 7'h43; // C
    6'b110_101: return 7'h56; // V
    6'b110_110: return 7'h42; // B
    6'b110_111: return 7'h4E; // N
    6'b111_000: return 7'h4D; // M
    6'b111_001: return 7'h2C; // ,
    6'b111_010: return 7'h2E; // .
    6'b111_011: return 7'h2F; // /
    6'b111_100: return 7'h5F; // \ SW40 _
    6'b111_101: return 7'h1C; // Left   US
    6'b111_110: return 7'h1D; // Down   GS
    6'b111_111: return 7'h1E; // Right  RS
  endcase
endfunction

endmodule