// MSMP: Make-cpu Simple Messaging Protocol
unsigned int tim_cnt __attribute__((at(0x02)));
unsigned int kbc_queue __attribute__((at(0x24)));
unsigned int kbc_status __attribute__((at(0x26)));
unsigned int uart2_data __attribute__((at(0x2C)));
unsigned int uart2_flag __attribute__((at(0x2E)));
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

void lcd_cmd(int cmd) {
  lcd_out8(0, cmd);
}

void lcd_init() {
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_cmd(0x28);
  lcd_cmd(0x0f);
  lcd_cmd(0x06);
  lcd_cmd(0x01);

  gpio = 0x80; // バックライト点灯
}

void lcd_putc(int ch) {
  lcd_out8(4, ch);
}

void lcd_puts(char *s) {
  while (*s) {
    lcd_putc(*s++);
  }
}

unsigned int recv_byte() {
  while ((uart2_flag & 0x01) == 0);
  return uart2_data;
}

void send_byte(int data) {
  while ((uart2_flag & 0x04) == 0);
  uart2_data = data;
}

void send_str(char *s) {
  while (*s) {
    delay_ms(20);
    send_byte(*s++);
  }
}

void int2hex(unsigned int val, char *s, int n) {
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

int strlen(char *s) {
  int i = 0;
  while (*s) {
    ++s;
    ++i;
  }
  return i;
}

int get_key() {
  while ((kbc_status & 0xff) == 0);
  return kbc_queue;
}

int strncmp(char *a, char *b, int n) {
  int i;
  for (i = 0; i < n; i++) {
    int v = a[i] - b[i];
    if (v != 0 | a[i] == 0) {
      return v;
    }
  }
  return 0;
}

int chartoi(char c) {
  if ('0' <= c & c <= '9') {
    return c - '0';
  }
  if (c >= 'a') {
    c -= 0x20;
  }
  if ('A' <= c & c <= 'F') {
    return c - 'A' + 10;
  }
  return -1;
}

int strtoi(char *s, char **endptr, int base) {
  int v = 0;
  int i;
  while (1) {
    i = chartoi(*s);
    if (i < 0 | i >= base) {
      break;
    }
    ++s;
    v = base*v + i;
  }
  *endptr = s;
  return v;
}

void strcpy(char *dst, char *src) {
  while (*src) {
    *dst++ = *src++;
  }
  *dst = 0;
}

int main() {
  int i;
  int my_addr = 5;
  int to_addr = 8;
  char buf[5];
  char greet_body[64];

  char *node_names[16]; // node_names[ADDR] = NAME

  strcpy(greet_body, "This is ComProc");

  node_names[my_addr] = "ComProc";
  node_names[8] = "NLP-16A";

  lcd_init();

  led_port = 0;
  int caps = 0;
  int shift = 0;
  while (1) {
    if (uart2_flag & 0x01) { // rx full
      lcd_cmd(0x01); // clear

      unsigned int addr_byte = recv_byte();
      int2hex(addr_byte, buf, 2);
      lcd_puts("MSG:d=");
      lcd_putc(buf[0]);
      lcd_puts(" s=");
      lcd_putc(buf[1]);
      lcd_puts(" t=");

      unsigned int len_byte = recv_byte();
      lcd_putc('0' + (len_byte >> 6));
      lcd_puts(" l=");
      int2hex(len_byte, buf, 2);
      lcd_putc(buf[0]);
      lcd_putc(buf[1]);
      lcd_cmd(0xC0);

      unsigned int dst = addr_byte >> 4;
      unsigned int src = addr_byte & 0xF;
      if (src == my_addr) { // 自分が送ったメッセージが 1 周した
        lcd_puts("CIRCLED");
        // 読み捨てる
        for (i = 0; i < len_byte; ++i) {
          recv_byte();
        }
      } else {
        if (dst == 15 | dst == my_addr) { // 自分宛てメッセージを受け取った
          for (i = 0; i < len_byte; ++i) {
            lcd_putc(recv_byte());
          }
        }
        if (dst == my_addr) { // 返信する
          char *to_name = node_names[src];
          char *msg = "Reply from ComProc!";
          send_byte((src << 4) | my_addr);
          send_byte(6 + strlen(to_name) + 2 + strlen(msg));
          send_str("Hello ");
          send_str(to_name);
          send_str("! ");
          send_str(msg);
        } else { // 次ノードへ転送
          lcd_puts("FORWARDING");
          send_byte(addr_byte);
          send_byte(len_byte);
          for (i = 0; i < len_byte; ++i) {
            send_byte(recv_byte());
          }
        }
      }
    } else if (kbc_status & 0xff) {
      lcd_cmd(0x01); // クリア

      char cmd[80];
      int key;
      i = 0;
      while ((key = get_key()) != '\n') {
        if (key == '\b') {
          if (i > 0) {
            i--;
            lcd_cmd(0x80 + i);
            lcd_putc(' ');
            lcd_cmd(0x80 + i);
          }
        } else if (key == 0x0E) { // Shift
          shift = 1;
          led_port |= 0x02;
        } else if (key == 0x8E) { // Shift (break)
          shift = 0;
          led_port &= 0xfd;
        } else if (key == 0x0F) { // Caps
          caps = !caps;
          led_port = (led_port & 0xfe) | caps;
        } else if (0x20 <= key & key < 0x80) {
          if ('A' <= key && key <= 'Z' && (caps ^ shift) == 0) {
            key += 0x20;
          }
          cmd[i++] = key;
          lcd_putc(key);
        }
      }
      cmd[i] = 0;

      if (strncmp(cmd, "greet ", 6) == 0) {
        char *msg = greet_body;
        char *endptr;
        int dst_addr = strtoi(cmd + 6, &endptr, 10);
        char *dst_name = node_names[dst_addr];

        send_byte((dst_addr << 4) | my_addr);
        delay_ms(20);
        if (*endptr == ' ') {
          msg = endptr + 1;
        }
        send_byte(6 + strlen(dst_name) + 2 + strlen(msg));
        send_str("Hello ");
        send_str(dst_name);
        send_str("! ");
        send_str(msg);
      } else if (strncmp(cmd, "send ", 5) == 0) {
        char *endptr;
        int dst_addr = strtoi(cmd + 5, &endptr, 10);
        if (*endptr == ' ') {
          char *msg = endptr + 1;
          send_byte((dst_addr << 4) | my_addr);
          delay_ms(20);
          send_byte(strlen(msg));
          send_str(msg);
        }
      } else if (strncmp(cmd, "set greet ", 10) == 0) {
        strcpy(greet_body, cmd + 10);
      } else if (strncmp(cmd, "show greet", 10) == 0) {
        lcd_cmd(0xc0);
        for (i = 0; greet_body[i] && i < 20; ++i) {
          lcd_putc(greet_body[i]);
        }
        lcd_cmd(0x94);
        for (i; greet_body[i] && i < 40; ++i) {
          lcd_putc(greet_body[i]);
        }
        lcd_cmd(0xd4);
        for (i; greet_body[i] && i < 60; ++i) {
          lcd_putc(greet_body[i]);
        }
      } else {
        lcd_cmd(0xc0);
        lcd_puts("Unknown cmd");
      }

      get_key(); // Enter リリースを読み飛ばす
    }
  }

  /*
  send_byte((to_addr << 4) | my_addr);
  delay_ms(20);
  send_byte(7);
  int i;
  for (i = 0; i < 7; ++i) {
    delay_ms(20);
    send_byte("ComProc"[i]);
  }
  delay_ms(2000);
  */

  return 0;
}
