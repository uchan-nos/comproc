/* このファイルを更新したら、次のコマンドで ipl_lo.hex と ipl_hi.hex も更新する。
 * ../../tool/generate-ipl.sh ipl.c
 */
int tim_cnt __attribute__((at(0x02)));
char led_port __attribute__((at(0x80)));
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

void lcd_init() {
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28);
  lcd_out8(0, 0x0f);
  lcd_out8(0, 0x06);
  lcd_out8(0, 0x01);
}

void lcd_puts(char *s) {
  while (*s) {
    lcd_out8(4, *s++);
  }
}

int main() {
  lcd_init();
  lcd_out8(0, 0x80);
  lcd_puts("ComProc MPU IPL");
  lcd_out8(0, 0xc0);
  lcd_puts("loaded at 0x0300");

  while (1) {
    led_port = 0x55;
    delay_ms(300);
    led_port = 0xaa;
    delay_ms(300);
  }
  return 0;
}
