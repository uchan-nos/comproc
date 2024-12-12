#include "mmio.h"
#include "delay.h"
#include "lcd.h"

int main() {
  int i;

  lcd_init();

  lcd_out8(0, 0x80);
  lcd_puts("OSC2024 Tokyo/Fall");
  lcd_out8(0, 0xc0);
  lcd_puts("»²ÎÞ³½Þ¥×ÎÞ É ÌÞ°½");
  lcd_out8(0, 0x94);
  lcd_puts("- Brack: markup lang");
  lcd_out8(0, 0xd4);
  lcd_puts("- ComProc PC (ºÚ!)");

  return 1;
}
