#include "mmio.h"
#include "delay.h"
#include "lcd.h"

char cmd;
int cmd_received = 0;

void _ISR() {
  if (uart_flag & 1) {
    cmd = uart_data;
    cmd_received = 1;
  }
}

void lcd_outs(int pos, char *s) {
  lcd_out8(0, pos);
  while (*s) {
    lcd_out8(4, *s++);
  }
}

void char_to_hex(char *s, char v) {
  int digit = v & 0x0f;
  if (digit < 10) {
    s[1] = digit + '0';
  } else {
    s[1] = digit - 10 + 'A';
  }
  digit = v >> 4;
  if (digit < 10) {
    s[0] = digit + '0';
  } else {
    s[0] = digit - 10 + 'A';
  }
}

int main(int *info) {
  int i;
  char pattern = 0x13;
  char *msg = "cmd=__";

  __builtin_set_isr(info[0] + _ISR);
  uart_flag = 2; // 受信割り込みを有効化

  lcd_init();
  lcd_outs(0x80, "Waiting uart...");

  while (1) {
    if (cmd_received) {
      cmd_received = 0;
      char_to_hex(msg + 4, cmd);
      lcd_outs(0xc0, msg);

      for (i = 0; i < 2; i++) {
        if (cmd < 16) {
          led_port = 0x10 + cmd;
        } else {
          led_port = 0xa5;
        }
        timer_cnt = 500;
        while (timer_cnt > 0);
        if (cmd < 16) {
          led_port = 0;
        } else {
          led_port = 0x5a;
        }
        timer_cnt = 500;
        while (timer_cnt > 0);
      }
    } else {
      led_port = pattern;
      pattern = (pattern << 1) | (pattern >> 7);
      timer_cnt = 500;
      while (timer_cnt > 0);
    }
  }
}
