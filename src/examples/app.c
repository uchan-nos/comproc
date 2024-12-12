#include "mmio.h"
#include "delay.h"
#include "lcd.h"

int get_key() {
  while ((kbc_status & 0xff) == 0);
  return kbc_queue;
}

int lcd_at(int linear_pos) {
  if (linear_pos < 20) {
    linear_pos += 0xc0;
  } else if (linear_pos < 40) {
    linear_pos += 0x94 - 20;
  } else if (linear_pos < 60) {
    linear_pos += 0xd4 - 40;
  } else {
    return -1;
  }
  lcd_out8(0, linear_pos);
  return linear_pos;
}

void play_bootsound() {
  int i;
  int j;
  for (i = 0; i < 100; i++) {
    gpio |= 0x40;
    for (j = 0; j < 200; j++);
    gpio &= ~0x40;
    for (j = 0; j < 200; j++);
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

int main(int *info) {
  char buf[5];
  led_port = 0;

  lcd_init();

  play_bootsound();

  int2hex(info[0], buf, 4);
  buf[4] = 0;
  lcd_out8(0, 0x94 + 8);
  lcd_puts("info[0]=");
  lcd_puts(buf);

  lcd_out8(0, 0x80);
  lcd_puts("waiting enter...");
  lcd_out8(0, 0xc0);

  int value = 0;
  while (1) {
    int key = get_key();
    if (key == '\n') { // Enter
      play_bootsound();
      break;
    } else if ('0' <= key && key <= '9') {
      value = value * 10 + (key - '0');
      lcd_out8(4, key);
    }
  }

  return value;
}
