void delay_ms(int ms) {
  int *t = 2;
  *t = ms;
  while (*t > 0) {}
}

void led_out(int val) {
  char *p = 0x80;
  *p = val;
  delay_ms(500);
  *p = 0;
  delay_ms(500);
}

int main() {
  led_out(0xaa);
  led_out(0x55);
  return 0;
}
