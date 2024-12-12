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
    gpio = 0x40;
    for (j = 0; j < 200; j++);
    gpio = 0x00;
    for (j = 0; j < 200; j++);
  }
}

int main() {
  led_port = 0;

  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28);
  lcd_out8(0, 0x0f);
  lcd_out8(0, 0x06);
  lcd_out8(0, 0x01);

  play_bootsound();

  gpio = 0x80;

  lcd_out8(0, 0x80);
  lcd_puts("Keyboard Sample");

  int i = 0;
  int caps = 0;
  int shift = 0;
  lcd_at(0);
  while (1) {
    int key = get_key();
    if (key == '\b') { // Backspace
      if (i > 0) {
        i--;
        lcd_at(i);
        lcd_out8(4, ' ');
        lcd_at(i);
      }
    } else if (key == '\n') { // Enter
      lcd_out8(0, 0x01);
      lcd_out8(0, 0x80);
      lcd_puts("Keyboard Sample");
      i = 0;
      lcd_at(0);
    } else if (key == 0x0E) { // Shift
      shift = 1;
      led_port |= 0x02;
    } else if (key == 0x8E) { // Shift (break)
      shift = 0;
      led_port &= 0xfd;
    } else if (key == 0x0F) { // Caps
      caps = 1 - caps;
      led_port = (led_port & 0xfe) | caps;
    } else if (0x20 <= key && key < 0x80) {
      if ('A' <= key && key <= 'Z' && (caps ^ shift) == 0) {
        key += 0x20;
      }
      if (i < 60) {
        lcd_out8(4, key);
        i++;
        lcd_at(i);
      }
    }
  }
  return 0;
}
