int delay_ms(int ms) {
  int *t = 2;
  *t = ms;
  while (*t > 0) {}
  return 0;
}

int lcd_out4(int rs, int val) {
  char *p = 0x81;
  *p = (val << 4) | rs | 1;
  delay_ms(2);
  *p = *p & 0xfe;
  return delay_ms();
}

int lcd_out8(int rs, int val) {
  lcd_out4(rs, val >> 4);
  return lcd_out4(rs, val);
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
