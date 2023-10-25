int timer_cnt __attribute__((at(2)));
int uart_data __attribute__((at(6)));
int uart_flag __attribute__((at(8)));
char led __attribute__((at(0x80)));
char lcd_port __attribute__((at(0x81)));

char cmd;
int cmd_received = 0;

void _ISR() {
  if (uart_flag & 1) {
    cmd = uart_data;
    cmd_received = 1;
  }
}

void delay_ms(int ms) {
  timer_cnt = ms;
  while (timer_cnt > 0);
}

void lcd_out4(int rs, int val) {
  lcd_port = val | rs | 1;
  delay_ms(2);
  lcd_port = lcd_port & 0xfe;
}

void lcd_out8(int rs, int val) {
  lcd_out4(rs, val & 0xf0);
  lcd_out4(rs, val << 4);
}

void lcd_init() {
  lcd_out4(0, 0x30);
  lcd_out4(0, 0x30);
  lcd_out4(0, 0x30);
  lcd_out4(0, 0x20);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28);
  lcd_out8(0, 0x0f);
  lcd_out8(0, 0x06);
  lcd_out8(0, 0x01);
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

int main() {
  int i;
  char pattern = 0x13;
  char *msg = "cmd=__";

  asm("push _ISR\n\t"
      "isr");
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
          led = 0x10 + cmd;
        } else {
          led = 0xa5;
        }
        timer_cnt = 500;
        while (timer_cnt > 0);
        if (cmd < 16) {
          led = 0;
        } else {
          led = 0x5a;
        }
        timer_cnt = 500;
        while (timer_cnt > 0);
      }
    } else {
      led = pattern;
      pattern = (pattern << 1) | (pattern >> 7);
      timer_cnt = 500;
      while (timer_cnt > 0);
    }
  }
}
