int tim_cnt __attribute__((at(0x02)));
int adc_result __attribute__((at(0x0A)));
char led __attribute__((at(0x80)));

void delay_ms(int ms) {
  tim_cnt = ms;
  while (tim_cnt > 0) {}
}

int main() {
  while (1) {
    led = adc_result;
    delay_ms(100);
  }
  return 0;
}
