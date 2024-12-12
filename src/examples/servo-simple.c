#include "mmio.h"
#include "delay.h"
#include "lcd.h"

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
