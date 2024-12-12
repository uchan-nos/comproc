int tim_cnt __attribute__((at(0x02)));
unsigned int kbc_queue __attribute__((at(0x24)));
unsigned int kbc_status __attribute__((at(0x26)));
char led_port __attribute__((at(0x80)));
char lcd_port __attribute__((at(0x81)));
char gpio __attribute__((at(0x82)));

void delay_ms(int ms) {
  tim_cnt = ms;
  while (tim_cnt > 0);
}

void lcd_out4(int rs, int val) {
  lcd_port = (val << 4) | 8 | rs | 1;
  delay_ms(2);
  lcd_port = lcd_port & 0xfe;
}

void lcd_out8(int rs, int val) {
  lcd_out4(rs, val >> 4);
  lcd_out4(rs, val & 0x0f);
}

void lcd_puts(char *s) {
  int i;
  for (i = 0; s[i]; i++) {
    lcd_out8(4, s[i]);
  }
}

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
