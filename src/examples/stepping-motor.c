int tim_cnt __attribute__((at(0x02)));
char led __attribute__((at(0x80)));
char gpio __attribute__((at(0x82)));

void delay_ms(int ms) {
  tim_cnt = ms;
  while (tim_cnt > 0) {}
}

void out(char val, int ms) {
  if (ms <= 4) {
    gpio = led = val;
    delay_ms(ms);
    return;
  }

  for (; ms > 0; ms -= 4) {
    gpio = led = val;
    delay_ms(2);
    gpio = led = 0;
    delay_ms(2);
  }
}

int main() {
  int i;
  int j;
  int d = 4;
  for (j = 0; j < 8; j++) {
    for (i = 0; i < 64; i++) {
      out(0x05, d);
      out(0x06, d);
      out(0x0a, d);
      out(0x09, d);
    }
    out(0x09, d * 256);
  }
  gpio = 0;
  return 0;
}
