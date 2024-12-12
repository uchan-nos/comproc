#include "mmio.h"
#include "delay.h"
#include "lcd.h"

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

  while (!stop_btn) {
    v = adc_result;
    led_port = v;

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
