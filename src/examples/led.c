int delay_ms(int ms) {
  int *t = 0;
  *t = ms;
  while (*t > 0) {}
  return 0;
}

int led_out(int val) {
  char *p = 0x1c;
  *p = val;
  delay_ms(500);
  *p = 0;
  delay_ms(500);
  return 0;
}

int main() {
  led_out(0xaa);
  led_out(0x55);
  return 0;
}
