int spi_dat __attribute__((at(0x020)));
int spi_ctl __attribute__((at(0x022)));

int tim_cnt __attribute__((at(0x02)));
char lcd_port __attribute__((at(0x81)));

int cnt;

void delay_ms(int ms) {
  tim_cnt = ms;
  while (tim_cnt > 0) {}
}

void lcd_out4(int rs, int val) {
  lcd_port = (val << 4) | rs | 1;
  delay_ms(2);
  lcd_port = lcd_port & 0xfe;
  //delay_ms(1);
}

void lcd_out8(int rs, int val) {
  lcd_out4(rs, val >> 4);
  lcd_out4(rs, val & 0x0f);
}

void lcd_cmd(int cmd) {
  lcd_out8(0, cmd);
}

void lcd_putc(int ch) {
  lcd_out8(4, ch);
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
}

void lcd_puts(char *s) {
  while (*s) {
    lcd_putc(*s++);
  }
}

void lcd_clear() {
  lcd_cmd(0x01);
}

void lcd_puts_addr(int addr, char *s) {
  lcd_cmd(0x80 + addr);
  lcd_puts(s);
}

void assert_cs() {
  spi_ctl = 0;
}

void deassert_cs() {
  spi_ctl = 2;
}

void wait_spi_ready() {
  while ((spi_ctl & 1) == 0);
}

void send_spi(int v) {
  spi_dat = v;
  wait_spi_ready();
}

int recv_spi_16() {
  int v;
  send_spi(0xff);
  v = spi_dat << 8;
  send_spi(0xff);
  v = spi_dat | v;
  return v;
}

// SD の R1 レスポンスは最上位ビットが 0
//
// 戻り値
// >=0: SD からのレスポンス
// <0:  レスポンス受信がタイムアウト
int wait_sd_response() {
  int i;
  int resp = spi_dat;
  for (i = 0; i < 8; i++) {
    if ((resp & 0x80) == 0) {
      return resp;
    }
    send_spi(0xff);
    resp = spi_dat;
  }
  return -resp;
}

int wait_sd_r1() {
  int r1 = wait_sd_response();
  send_spi(0xff);
  return r1;
}

int wait_sd_r1_32(int *high, int *low) {
  int r1 = wait_sd_response();
  *high = recv_spi_16();
  *low = recv_spi_16();
  send_spi(0xff);
  return r1;
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

void int2dec(int val, char *s, int n) {
  int i;
  int dec_arr[6];
  int digit;
  dec_arr[0] = 1;
  for (i = 1; i < n; i++) {
    dec_arr[i] = dec_arr[i - 1] * 10;
  }

  for (i = 0; i < n; i++) {
    int dec = dec_arr[n - i - 1];
    int digit = 0;
    while (val >= dec) {
      val -= dec;
      digit++;
    }
    s[i] = digit + '0';
  }
}

void send_sd_cmd(char cmd, int arg_high, int arg_low, char crc) {
  send_spi(0x40 + cmd);
  send_spi(arg_high >> 8);
  send_spi(arg_high & 0xff);
  send_spi(arg_low >> 8);
  send_spi(arg_low & 0xff);
  send_spi(crc); // CRC-7 + stop bit
}

void show_sd_cmd_error(char cmd, int r1, char *msg) {
  char buf[3];
  int digit10 = 0;
  while (cmd >= 10) {
    digit10++;
    cmd -= 10;
  }

  lcd_puts_addr(0x00, "CMD");
  if (digit10 > 0) {
    lcd_putc('0' + digit10);
  }
  lcd_putc('0' + cmd);
  lcd_puts(" -> ");

  if (r1 < 0) {
    lcd_puts("timeout");
  } else {
    int2hex(r1, buf, 2);
    buf[2] = '\0';
    lcd_puts(buf);
  }

  lcd_puts_addr(0x40, msg);
}

// return minus value on error
// bit 0: V2 (0: SDv1, 1: SDv2 or later)
// bit 1: CCS (Card Capacity Status)
int sd_init() {
  int i;
  int r1;
  int hi; // response high 16 bits
  int lo; // response low 16 bits
  int sdv; // 1 => SDSC, 2 => SDHC/SDXC or later

  deassert_cs(); // CS = 1
  for (i = 0; i < 10; i++) {
    send_spi(0xff);
  }

  //delay_ms(500);
  lcd_clear();

  assert_cs(); // CS = 0
  send_sd_cmd(0, 0, 0, 0x95); // CMD0
  r1 = wait_sd_r1();
  deassert_cs(); // CS = 1

  if (r1 != 0x01) { // 正常に Idle State にならなかった
    show_sd_cmd_error(0, r1, "FAILED");
    return -1;
  }

  assert_cs(); // CS = 0
  send_sd_cmd(8, 0x0000, 0x01aa, 0x87); // CMD8
  // CMD8 は CRC を正しくしないとエラーになる
  r1 = wait_sd_r1_32(&hi, &lo);
  deassert_cs(); // CS = 1
  if (r1 < 0) {
    show_sd_cmd_error(0, r1, "FAILED");
    return -1;
  } else if (r1 & 4) { // illegal command => SDSC か、あるいは SD ではない何か
    sdv = 1;
  } else if ((r1 & 0xfe) == 0) { // SDHC/SDXC or later
    sdv = 2;
  } else {
    show_sd_cmd_error(0, r1, "FAILED");
    return -1;
  }

  if (sdv >= 2) {
    if (r1 != 0x01) { // 正常に Idle State にならなかった
      show_sd_cmd_error(8, r1, "FAILED");
      return -1;
    }
    if (lo != 0x01aa) {
      show_sd_cmd_error(8, r1, "FAILED (01AA)");
      return -1;
    }
  }

  for (i = 0; i < 200; i++) {
    assert_cs(); // CS = 0
    send_sd_cmd(55, 0, 0, 0); // CMD55
    r1 = wait_sd_r1();
    deassert_cs(); // CS = 1

    if (r1 != 1) {
      show_sd_cmd_error(55, r1, "FAILED");
      return -1;
    }

    assert_cs(); // CS = 0
    hi = (sdv >= 2) << 14; // HCS=1 if sd version >= 2
    send_sd_cmd(41, hi, 0, 0);
    r1 = wait_sd_r1();
    deassert_cs(); // CS = 1
    if (r1 == 0x01) {        // In Idle State
      continue;
    } else if (r1 == 0x00) { // Idle State を抜けた
      break;
    } else {                 // その他の状態
      show_sd_cmd_error(41, r1, "FAILED");
      return -1;
    }

    delay_ms(10);
  }

  if (r1 != 0) {
    return -1;
  }

  assert_cs();
  send_sd_cmd(58, 0, 0, 0); // Read OCR
  r1 = wait_sd_r1_32(&hi, &lo);
  deassert_cs();

  int res;
  res = 0;
  if (sdv >= 2) {
    res = res | 0x0001;
  }
  if ((hi & 0xc000) == 0xc000) {
    res = res | 0x0002;
  }
  return res;
}

int sd_get_read_bl_len(int *csd) {
  return csd[2] & 0x000f; // [83:80]
}

int sd_get_capacity_mib_csdv1(unsigned int *csd) {
  int c_size;
  int c_size_mult;
  int read_bl_len;
  int shift;

  c_size = (csd[3] & 0x03ff) << 2;        // [73:64]
  c_size = c_size | (csd[4] >> 14); // [63:62]
  c_size_mult = (csd[4] & 3) << 1;                  // [49:48]
  c_size_mult = c_size_mult | (csd[5] >> 15); // [47]
  read_bl_len = sd_get_read_bl_len(csd);

  // memory capacity = (C_SIZE + 1) * 2^(C_SIZE_MULT + 2 + READ_BL_LEN)
  shift =
    20                  // 1MiB == 2^20
    - read_bl_len       // ブロック数（の指数）
    - (c_size_mult + 2);// 計数（の指数）
  // read_bl_len == 10
  // c_size_mult == 7
  // shift == 1
  // c_size == 0x0f02 == 3842
  //
  // BLOCK_LEN = 1024
  // MULT = 512
  // BLOCKNR = 3843 * MULT = 1921.5 KiB
  // cap = BLOCKNR * BLOCK_LEN = 1921.5 MiB

  if (shift >= 0) {
    return (c_size + 1) >> shift;
  } else {
    return (c_size + 1) << -shift;
  }
}

int sd_get_capacity_mib_csdv2(unsigned int *csd) {
  unsigned int c_size_h;
  unsigned int c_size_l;
  int cap_mib;

  // C_SIZE: [69:48]
  // csd[0] = [127:112]
  // csd[3] = [79:64]
  // csd[4] = [63:48]
  c_size_h = (csd[3] & 0x003f); // [69:64]
  c_size_l = csd[4];            // [63:48]

  cap_mib = c_size_l >> 1;
  cap_mib = cap_mib | (c_size_h << 15);
  return cap_mib;
}

// CSD レジスタを取得する
int sd_read_csd(unsigned int *csd) {
  int i;
  int r1;

  assert_cs();
  send_sd_cmd(9, 0, 0, 0); // CMD9 (SEND_CSD)
  r1 = wait_sd_r1();
  if (r1 != 0) {
    return -1;
  }

  while (spi_dat != 0xfe) { // Start Block トークンを探す
    send_spi(0xff);
  }
  for (i = 0; i < 9; i++) {
    csd[i] = recv_spi_16();
  }
  deassert_cs();
  return 0;
}

// MiB 単位の容量
int sd_get_capacity_mib(unsigned int *csd) {
  int csdv;

  csdv = csd[0] >> 14;
  if (csdv == 0) { // Ver.1
    return sd_get_capacity_mib_csdv1(csd);
  } else if (csdv >= 1) { // Ver.2 or Ver.3
    return sd_get_capacity_mib_csdv2(csd);
  }
  return -1;
}

int sd_set_block_len_512() {
  int r1;

  assert_cs(); // CS = 0
  send_sd_cmd(16, 0, 512, 0); // CMD16
  r1 = wait_sd_r1();
  deassert_cs(); // CS = 1
  if (r1 != 0) {
    show_sd_cmd_error(16, r1, "FAILED");
    return -1;
  }
  return 0;
}

// 1 ブロック読み込み
int sd_read_block(unsigned int *buf, int block_addr, int ccs) {
  int i;
  int r1;

  int addr_hi;
  int addr_lo;
  if (ccs) {
    addr_lo = block_addr;
    addr_hi = 0;
  } else {
    // バイトアドレスに変換
    addr_lo = block_addr << 9;
    addr_hi = block_addr >> (16 - 9);
  }

  assert_cs();
  send_sd_cmd(17, addr_hi, addr_lo, 0); // CMD17 (SEND_SINGLE_BLOCK)
  r1 = wait_sd_r1();
  if (r1 != 0) {
    show_sd_cmd_error(17, r1, "FAILED");
    return -1;
  }

  while (spi_dat != 0xfe) { // Start Block トークンを探す
    send_spi(0xff);
  }
  for (i = 0; i < 256; i++) {
    buf[i] = recv_spi_16();
  }
  deassert_cs();
  return 0;
}

int main() {
  int i;
  int sdinfo;
  int block_len;
  int cap_mib;
  char buf[5];
  unsigned int csd[9]; // 末尾は 16 ビットの CRC
  unsigned int block_buf[256];
  unsigned int lba_start_lo;

  lcd_init();

  sdinfo = sd_init();
  if (sdinfo < 0) {
    return 1;
  }

  lcd_puts("SDv");
  if (sdinfo & 0x0001) {
    lcd_puts("2+");
  } else {
    lcd_puts("1 ");
  }
  if (sdinfo & 0x0002) {
    lcd_puts("HC");
  } else {
    lcd_puts("SC");
  }

  if (sd_read_csd(csd) < 0) {
    return 1;
  }

  cap_mib = sd_get_capacity_mib(csd);
  //lcd_puts(" 0x");
  //int2hex(cap_mib, buf, 4);
  lcd_puts(" ");
  int2dec(cap_mib, buf, 4);
  buf[4] = 0;
  lcd_puts(buf);
  lcd_puts("MB");

  block_len = sd_get_read_bl_len(csd);

  if (block_len != 9) {
    if (sd_set_block_len_512() < 0) {
      return 1;
    }
  }

  // sdinfo bit1 が CCS
  if (sd_read_block(block_buf, 0, (sdinfo & 2) != 0) < 0) {
    return 1;
  }
  lcd_cmd(0xc0);

  // MBR か PBR の判定
  if (block_buf[255] != 0x55AA) { // 最終 2 バイトが 55 AA ではない
    lcd_puts("not found 55 AA");
    return 1;
  }
  if ((((block_buf[0] & 0x00ff) == 0xEB && (block_buf[1] >> 8) == 0x90)) ||
      ((block_buf[0] & 0x00ff) == 0xE9)) {
    lcd_puts("PBR");
  } else if (((block_buf[223] >> 8) & 0x7f) == 0) {
    //char *p = "DEF";
    //lcd_puts("DEF");
    //lcd_puts(p);
    //while (*p) {
    //  //lcd_putc(*p);
    //  //lcd_out8(4, *p);
    //  //lcd_out4(4, *p >> 4);
    //  //lcd_out4(4, *p & 0x0f);
    //  lcd_out4(4, *p >> 4);
    //  lcd_out4(4, *p & 0x0f);
    //  p++;
    //}
    //for (i = 0; i < 3; i++) {
    //  lcd_out8(4, *p++);
    //}
    //lcd_putc('D');
    //lcd_putc('E');
    //lcd_putc('F');
    //lcd_puts("MBR ");
    //lcd_puts("MBR ");
    lcd_puts("ABC");
    lcd_puts("DEF");
    lcd_puts("GHI");
    //int2hex(block_buf[223 + 2] >> 8, buf, 2);
    //buf[2] = 0;
    //lcd_puts(buf);
    //lcd_puts(" ");

    lba_start_lo = block_buf[223 + 4];
    // LBA Start はリトルエンディアンなので、エンディアンを変換する
    lba_start_lo = (lba_start_lo >> 8) | (lba_start_lo << 8);

    //int2hex(lba_start_lo, buf, 4);
    //buf[4] = 0;
    //lcd_puts(buf);
  } else {
    lcd_puts("Unknown BS");
  }

  //return cnt;
  return 0;
}
