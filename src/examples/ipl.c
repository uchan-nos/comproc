/* このファイルを更新したら、次のコマンドで ipl_lo.hex と ipl_hi.hex も更新する。
 * ../../tool/generate-ipl.sh ipl.c
 */
int tim_cnt __attribute__((at(0x02)));

int uf_xadr    __attribute__((at(0x10)));
int uf_yadr    __attribute__((at(0x12)));
int uf_flags   __attribute__((at(0x14)));
int uf_din_lo  __attribute__((at(0x18)));
int uf_din_hi  __attribute__((at(0x1A)));
int uf_dout_lo __attribute__((at(0x1C)));
int uf_dout_hi __attribute__((at(0x1E)));

char led_port __attribute__((at(0x80)));
char lcd_port __attribute__((at(0x81)));

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

void lcd_init() {
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 3);
  lcd_out4(0, 2);

  // ここから 4 ビットモード
  lcd_out8(0, 0x28);
  lcd_out8(0, 0x0f);
  lcd_out8(0, 0x06);
  lcd_out8(0, 0x01);
}

void lcd_puts(char *s) {
  while (*s) {
    lcd_out8(4, *s++);
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
  char buf[7];
  int data_lo;
  int data_hi;

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
  int2hex(data_hi, buf, 2);
  int2hex(data_lo, buf + 2, 4);
  buf[6] = '\0';

  lcd_init();
  lcd_out8(0, 0xc0);
  lcd_puts("ExecCnt:0x");
  lcd_puts(buf);
  lcd_out8(0, 0x80);
  lcd_puts("ComProc MCU IPL");

  while (1) {
    led_port = 0x55;
    delay_ms(300);
    led_port = 0xaa;
    delay_ms(300);
  }
  return 0;
}
