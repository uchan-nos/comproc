int delay_ms() {
  int *t = 2;
  *t = 2;
  while (*t > 0) {}
  return 0;
}

int lcd_out4(int rs, int val) {
  char *p = 0x81;
  *p = val | rs | 1;
  delay_ms();
  *p = *p & 0xfe;
  return delay_ms();
}

int lcd_out8(int rs, int val) {
  lcd_out4(rs, val & 0xf0);
  return lcd_out4(rs, val << 4);
}

int main() {
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28);
  lcd_out8(0, 0x0f);
  lcd_out8(0, 0x06);
  lcd_out8(0, 0x01);

  return 1;
}

