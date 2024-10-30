int tim_cnt __attribute__((at(0x02)));
int i2c_data __attribute__((at(0x28)));
int i2c_status __attribute__((at(0x2A)));
char led_port __attribute__((at(0x80)));
char gpio __attribute__((at(0x82)));

void delay_ms(int ms) {
  tim_cnt = ms;
  while (tim_cnt > 0) {}
}

int wait_ready() {
  while ((i2c_status & 0x2) == 0);
  return (i2c_status >> 3) & 1; // ACK
}

// アドレスかデータ 1 バイトを送る
int i2c_send(int val) {
  i2c_data = val;
  return wait_ready();
}

// ストップビットを送る
void i2c_stop() {
  i2c_status = 4;
  wait_ready();
}

int main() {
  i2c_send(0x78);
  i2c_send(0x00); // 可変長コマンド
  i2c_send(0xA1); // セグメントリマップ（左右の描画方向設定）
  i2c_send(0xAF); // display ON
  i2c_send(0x8D); // チャージポンプ設定
  i2c_send(0x14); // チャージポンプ ON
  i2c_send(0x20); // アドレッシングモード設定
  i2c_send(0x02); // ページアドレッシングモード
  i2c_send(0x00); // 列開始アドレスの下位 4 ビットを 0 に設定
  i2c_send(0x10); // 列開始アドレスの上位 4 ビットを 0 に設定
  i2c_stop();

  unsigned char value = 0x03;
  for (int i = 0; i < 16; i++) {
    // 画面の初期化:黒塗り
    for (int page = 0; page < 8; page++) {
      i2c_send(0x78);
      i2c_send(0x00); // 可変長コマンド
      i2c_send(0xB0 | page);
      i2c_stop();

      i2c_send(0x78);
      i2c_send(0x40); // Co=0 & D/C#=1: 可変長データ
      for (int x = 0; x < 128; x++) {
        i2c_send(value);
      }
      i2c_stop();
    }

    delay_ms(20);
    value = (value << 1) | (value >> 7);
  }

  return 0;
}
