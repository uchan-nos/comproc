int delay_ms() {
  int *t = 0;
  *t = 2;
  while (*t > 0) {}
  return 0;
}

int lcd_out4(int rs, int val) {
  char *p = 0x1d;
  *p = (val << 4) | rs | 1;
  delay_ms();
  *p = *p & 0xfe;
  return delay_ms();
}

int lcd_out8(int rs, int val) {
  lcd_out4(rs, val >> 4);
  return lcd_out4(rs, val);
}

int main() {
  int i;
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
