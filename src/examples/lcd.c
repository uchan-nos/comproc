int delay_ms(int ms) {
  int *t = 0;
  *t = ms;
  while (*t > 0) {}
  return 0;
}

int lcd_out4(int rs, int val) {
  char *p = 0x1d;
  *p = (val << 4) | (rs << 2) | 1;
  delay_ms(1);
  *p = *p & 0xfe;
  delay_ms(2);
  return 0;
}

int lcd_out8(int rs, int val) {
  lcd_out4(rs, val >> 4);
  lcd_out4(rs, val);
  return 0;
}

int main() {
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28); // function set: 4bit, 2lines, 5x7dots
  lcd_out8(0, 0x0f); // display on/off: display on, cursor on, blink on
  lcd_out8(0, 0x06); // entry mode set: increment, with display shift
  lcd_out8(0, 0x01); // clear display

  lcd_out8(1, 'O');
  lcd_out8(1, 'S');
  lcd_out8(1, 'C');
  lcd_out8(1, '2');
  lcd_out8(1, '0');
  lcd_out8(1, '2');
  lcd_out8(1, '3');

  return 1;
}
