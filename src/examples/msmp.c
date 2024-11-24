// MSMP: Make-cpu Simple Messaging Protocol
unsigned int tim_cnt __attribute__((at(0x02)));
unsigned int adc_result __attribute__((at(0x0A)));
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

  // �������� 4 �r�b�g���[�h
  lcd_cmd(0x28);
  lcd_cmd(0x0f);
  lcd_cmd(0x06);
  lcd_cmd(0x01);

  gpio = 0x80; // �o�b�N���C�g�_��
}

void lcd_putc(int ch) {
  lcd_out8(4, ch);
}

void lcd_puts(char *s) {
  while (*s) {
    lcd_putc(*s++);
  }
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

void send_head(unsigned char addr, unsigned char len) {
  send_byte(addr);
  delay_ms(20);
  send_byte(len);
}

// MSMP ��M�o�b�t�@
// �擪 1 �o�C�g�͊Ǘ��t���O
//   0000 0000: �o�b�t�@�͋󂩁A��M��
//   0  len7  : �o�b�t�@�ɂ͗L���ȃ��b�Z�[�W������
//   1  len7  : �����t���[�����A�M���Ŏ�M�����~���ꂽ
unsigned char msmp_buf1[66];
unsigned char msmp_buf2[66];
int msmp_recv_index;
int msmp_recv_len = 65;

void _ISR() {
  unsigned char *buf;
  if (*msmp_buf1 == 0) {
    buf = msmp_buf1;
  } else if (*msmp_buf2 == 0) {
    buf = msmp_buf2;
  } else {
    return;
  }

  unsigned char dat = uart2_data;
  ++msmp_recv_index;
  buf[msmp_recv_index] = dat;
  if (msmp_recv_index == 2) { // len
    msmp_recv_len = buf[msmp_recv_index] + 2;
  }

  int recv_all = msmp_recv_index == msmp_recv_len;
  if (recv_all || dat == 0) {
    if (!recv_all) { // �����t���[�����A�M���ɂ���M���~������
      msmp_recv_index |= 0x80;
    }
    *buf = msmp_recv_index;
    msmp_recv_index = 0;
    msmp_recv_len = 65;
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

char greet_body[64];
int my_addr = 5;
char *node_names[16]; // node_names[ADDR] = NAME

void proc_cmd(char *cmd) {
  int i;
  if (strncmp(cmd, "greet ", 6) == 0) {
    char *msg = greet_body;
    char *endptr;
    int dst_addr = strtoi(cmd + 6, &endptr, 10);
    char *dst_name = node_names[dst_addr];

    if (*endptr == ' ') {
      msg = endptr + 1;
    }
    send_head((dst_addr << 4) | my_addr, 6 + strlen(dst_name) + 2 + strlen(msg));
    send_str("Hello ");
    send_str(dst_name);
    send_str("! ");
    send_str(msg);
  } else if (strncmp(cmd, "send ", 5) == 0) {
    char *endptr;
    int dst_addr = strtoi(cmd + 5, &endptr, 10);
    if (*endptr == ' ') {
      char *msg = endptr + 1;
      send_head((dst_addr << 4) | my_addr, strlen(msg));
      send_str(msg);
    }
  } else if (strncmp(cmd, "set greet ", 10) == 0) {
    strcpy(greet_body, cmd + 10);
  } else if (strncmp(cmd, "show greet", 11) == 0) {
    lcd_cmd(0x94);
    for (i = 0; greet_body[i] && i < 20; ++i) {
      lcd_putc(greet_body[i]);
    }
    lcd_cmd(0xd4);
    for (i; greet_body[i] && i < 40; ++i) {
      lcd_putc(greet_body[i]);
    }
  } else if (strncmp(cmd, "help", 5) == 0) {
    lcd_cmd(0x94);
    lcd_puts("greet DST           ");
    lcd_cmd(0xd4);
    lcd_puts("send DST MSG       \x7e");
    while (get_key() != '\x1e'); // �E����҂�
    lcd_cmd(0x94);
    lcd_puts("set greet MSG       ");
    lcd_cmd(0xd4);
    lcd_puts("show greet         \x7e");
    while (get_key() != '\x1e'); // �E����҂�
    lcd_cmd(0x94);
    lcd_puts("help                ");
    lcd_cmd(0xd4);
    lcd_puts("                    ");
  } else {
    lcd_cmd(0x94);
    lcd_puts("Unknown cmd");
    lcd_cmd(0xd4);
    for (i = 0; cmd[i] && i < 20; ++i) {
      lcd_putc(cmd[i]);
    }
  }
}

void play_sound(int pulse_width, int pulse_count) {
  int i;
  int j;
  for (i = 0; i < pulse_count; i++) {
    gpio |= 0x40;
    for (j = 0; j < pulse_width; j++);
    gpio &= 0xbf;
    for (j = 0; j < pulse_width; j++);
  }
}

int main() {
  int i;
  int to_addr = 8;
  char buf[5];
  char default_node_name[32];

  asm("push _ISR\n\tpop isr");
  uart2_flag = 2; // enable interrupt

  strcpy(greet_body, "This is ComProc");

  for (i = 0; i < 16; ++i) {
    char *p = default_node_name + 2*i;
    int2hex(i, p, 1);
    p[1] = 0;
    node_names[i] = p;
  }
  node_names[4] = "MNP004";
  node_names[my_addr] = "ComProc";
  node_names[8] = "NLP-16A";

  lcd_init();
  // NUL�����̃t�H���g��]��
  // 0  * _ _ * _
  // 1  * * _ * _
  // 2  * _ * * _
  // 3  * _ _ * _
  // 4  _ * _ _ _
  // 5  _ * _ _ _
  // 6  _ * _ _ _
  // 7  _ * * * _
  lcd_cmd(0x40);
  for (i = 0; i < 8; ++i) {
    lcd_putc("\x12\x1a\x16\x12\x08\x08\x08\x0e"[i]);
  }

  led_port = 0;
  int caps = 0;
  int shift = 0;
  char cmd[80];
  int cmd_i = 0;
  while (1) {
    unsigned char *msmp_buf = 0;
    if (*msmp_buf1) {
      msmp_buf = msmp_buf1;
    } else if (*msmp_buf2) {
      msmp_buf = msmp_buf2;
    }

    if (msmp_buf) {
      play_sound(1000, 20);
      lcd_cmd(0x80);

      unsigned int addr_byte = msmp_buf[1];
      unsigned int len_byte = msmp_buf[2];
      int2hex(addr_byte, buf, 2);
      lcd_puts("MSG");
      if (*msmp_buf & 0x80) {
        lcd_putc('!');
      } else {
        lcd_putc(':');
      }
      lcd_putc(buf[0]);
      lcd_putc(0x7e); // �E���
      lcd_putc(buf[1]);
      lcd_puts(" L=");

      int2hex(len_byte, buf, 2);
      lcd_putc(buf[0]);
      lcd_putc(buf[1]);
      lcd_putc(' ');

      unsigned int dst = addr_byte >> 4;
      unsigned int src = addr_byte & 0xF;
      if (src == my_addr) {
        lcd_puts("��ޯ÷�");
      } else if (dst == my_addr) {
        lcd_puts("��� �� ");
      } else if (dst == 15) {
        lcd_puts("��� �� ");
      } else {
        lcd_puts("�ݿ� ��");
      }
      lcd_cmd(0xC0);

      int body_len = len_byte & 0x3f;
      if (*msmp_buf & 0x80) {
        body_len = (*msmp_buf & 0x7f) - 2;
      }
      for (i = 0; i < body_len && i < 20; ++i) {
        lcd_putc(msmp_buf[3 + i]);
      }
      for (; i < 20; ++i) {
        lcd_putc(' ');
      }

      if (dst == my_addr) { // �������ă��b�Z�[�W�ɕԐM
        if (body_len == 3 && strncmp(msmp_buf + 3, "ADC", 3) == 0) {
          send_head((src << 4) | my_addr, 2);
          int2hex(adc_result, buf, 2);
          buf[2] = '\0';
          send_str(buf);

          lcd_cmd(0xc3);
          lcd_putc(0x7e);
          lcd_puts(buf);
        } else if (body_len >= 1 && msmp_buf[3] == 'H') {
          char *to_name = node_names[src];
          char *msg = "Reply from ComProc!";
          send_head((src << 4) | my_addr, 6 + strlen(to_name) + 2 + strlen(msg));
          send_str("Hello ");
          send_str(to_name);
          send_str("! ");
          send_str(msg);
        }
      } else { // �������Ăł͂Ȃ��̂Ŏ��m�[�h�֓]��
        send_head(addr_byte, len_byte);
        for (i = 0; i < len_byte; ++i) {
          delay_ms(20);
          send_byte(msmp_buf[i + 3]);
        }
      }
      *msmp_buf = 0;
    } else if (kbc_status & 0xff) {
      int key = kbc_queue;
      if (cmd_i == 0 && key < 0x80) {
        int i;
        lcd_cmd(0x94);
        for (i = 0; i < 20; ++i) {
          lcd_putc(' ');
        }
        lcd_cmd(0xd4);
        for (i = 0; i < 20; ++i) {
          lcd_putc(' ');
        }
      }

      if (key == '\n') { // Enter
        play_sound(200, 100);
        if (cmd_i > 0) {
          cmd[cmd_i] = '\0';
          proc_cmd(cmd);
        }
        cmd_i = 0;
      } else if (key == '\b') {
        if (cmd_i > 0) {
          cmd_i--;
          lcd_cmd(0x94 + cmd_i);
          lcd_putc(' ');
          lcd_cmd(0x94 + cmd_i);
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
        lcd_cmd(0x94 + cmd_i);
        lcd_putc(key);
        cmd[cmd_i++] = key;
      }
    }
  }

  return 0;
}
