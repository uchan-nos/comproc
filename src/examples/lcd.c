int tim_cnt __attribute__((at(0x02)));
char lcd_port __attribute__((at(0x81)));

void delay_ms(int ms) {
  tim_cnt = ms;
  while (tim_cnt > 0) {}
}

void lcd_out4(int rs, int val) {
  lcd_port = (val << 4) | rs | 1;
  delay_ms(2);
  lcd_port = lcd_port & 0xfe;
}

void lcd_out8(int rs, int val) {
  lcd_out4(rs, val >> 4);
  lcd_out4(rs, val & 0x0f);
}

int main() {
  int i;

  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28);
  lcd_out8(0, 0x0f);
  lcd_out8(0, 0x06);
  lcd_out8(0, 0x01);

  lcd_out8(0, 0x80);
  for (i = 0; i < 13; i++) {
    lcd_out8(4, "OSC2023 Tokyo"[i]);
  }
  lcd_out8(0, 0xc0);
  for (i = 0; i < 12; i++) {
    lcd_out8(4, "Cybozu Booth"[i]);
  }
  return 1;
}
