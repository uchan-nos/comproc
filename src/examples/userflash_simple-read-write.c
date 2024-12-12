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

void delay_10us() {
  int i;

  // 現状、1 ループに 15 命令ほどかかる
  // 15 * 6 = 90 命令
  // 92 命令 = 368 クロックで約 10us
  for (i = 0; i < 6; i++) {
    asm("nop");
  }
}

int main() {
  int i;
  char buf[9];
  int data_lo;
  int data_hi;
  buf[8] = '\0';

  lcd_init();
  lcd_out8(0, 0x80);
  lcd_puts("User Flash Test");

  // read XADR=0, YADR=0
  uf_flags = 0;
  uf_xadr = 0;
  uf_yadr = 0;
  uf_flags = 3;
  uf_flags = 7;
  uf_flags = 3;
  data_lo = uf_dout_lo;
  data_hi = uf_dout_hi;
  uf_flags = 0;

  data_lo++;
  if (data_lo == 0) {
    data_hi++;
  }

  // page erase XADR=0
  uf_flags = 0;
  uf_xadr = 0;
  uf_flags = 0x01; // XE=1
  uf_flags = 0x09; // ERASE=1
  delay_10us();
  uf_flags = 0x29; // NVSTR=1
  delay_ms(100);
  uf_flags = 0x21; // ERASE=0
  delay_10us();
  uf_flags = 0x01; // NVSTR=0
  uf_flags = 0x00; // XE=0
  delay_10us();

  // write XADR=0, YADR=0
  // flags: 5:nvstr 4:prog 3:erase 2:se 1:ye 0:xe
  uf_flags = 0x00; // SE=0, ERASE=0, YE=0
  uf_xadr = 0;
  uf_flags = 0x01; // XE=1
  uf_flags = 0x11; // PROG=1
  delay_10us();
  uf_flags = 0x31; // NVSTR=1
  uf_yadr = 0;
  uf_din_lo = data_lo;
  uf_din_hi = data_hi;
  delay_10us();
  uf_flags = 0x33; // YE=1
  delay_10us();
  uf_flags = 0x31; // YE=0
  uf_flags = 0x21; // PROG=0
  delay_10us();
  uf_flags = 0x01; // NVSTR=0
  uf_flags = 0x00; // XE=0

  // show data
  int2hex(data_hi, buf, 4);
  int2hex(data_lo, buf + 4, 4);

  lcd_out8(0, 0xc0);
  lcd_puts("[0,0]=0x");
  lcd_puts(buf);

  return 0;
}
