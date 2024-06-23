int tim_count __attribute__((at(0x02)));
int adc_result __attribute__((at(0x0A)));
char led_port __attribute__((at(0x80)));
int uart_data __attribute__((at(6)));
int uart_flag __attribute__((at(8)));

void delay_ms(int ms) {
  tim_count = ms;
  while (tim_count > 0) {}
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

void uart_puts(char *s) {
  while (*s) {
    while ((uart_flag & 4) == 0); // wait tx ready
    uart_data = *s;
    s++;
  }
}

int main() {
  char buf[3];
  int v;
  buf[2] = '\0';

  uart_puts("ADC Extension\n");

  while (1) {
    v = adc_result;
    led_port = v;

    int2hex(v, buf, 2);
    uart_puts("value=");
    uart_puts(buf);
    uart_puts("\n");

    delay_ms(1000);
  }
  return 0;
}
