int tim_cnt __attribute__((at(0x02)));
int adc_result __attribute__((at(0x0A)));
char led __attribute__((at(0x80)));
int lcd_port __attribute__((at(0x81)));

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

void int2hex(int val, char *s, int n) {
  int i;
  for (i = 0; i < n; i++) {
    int v = val & 0xf;
    val = val >> 4;
    if (v >= 10) {
      v += 'A' - 10;
    } else {
      v += '0';
    }
    s[n - 1 - i] = v;
  }
}

int main() {
  char buf[3];
  int v;
  int cnt = 0;
  buf[2] = '\0';

  lcd_init();
  lcd_out8(0, 0x80);
  lcd_puts("ADC Extension");
  lcd_out8(0, 0xc0);
  lcd_puts("value=");

  while (1) {
    v = adc_result;
    led = v;

    if (++cnt >= 3) {
      cnt = 0;

      int2hex(v, buf, 2);
      lcd_out8(0, 0xc6);
      lcd_puts(buf);
    }

    delay_ms(100);
  }
  return 0;
}
