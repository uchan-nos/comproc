int tim_cnt __attribute__((at(0x02)));
int adc_result __attribute__((at(0x0A)));
char led_port __attribute__((at(0x80)));
char lcd_port __attribute__((at(0x81)));
char gpio __attribute__((at(0x82)));

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
  int v;
  lcd_init();
  lcd_out8(0, 0x80);
  lcd_puts("Servo PID Ctrl");

  while (1) {
    v = adc_result;

    if (v > 0x80) {
      gpio = 0x01;
    } else if (v < 0x80) {
      gpio = 0x02;
    } else {
      gpio = 0x03;
    }

    led_port = v;
  }
  return 0;
}
