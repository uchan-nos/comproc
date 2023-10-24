int timer_cnt __attribute__((at(2)));
int uart_data __attribute__((at(6)));
int uart_flag __attribute__((at(8)));
char led __attribute__((at(0x80)));

char cmd;
int cmd_received = 0;

void _ISR() {
  if (uart_flag & 1) {
    cmd = uart_data;
    cmd_received = 1;
  }
}

int main() {
  int i;
  char pattern = 0x13;

  asm("push _ISR\n\t"
      "isr");
  uart_flag = 2; // 受信割り込みを有効化

  while (1) {
    if (cmd_received) {
      cmd_received = 0;
      for (i = 0; i < 2; i++) {
        if (cmd < 16) {
          led = 0x10 + cmd;
        } else {
          led = 0xa5;
        }
        timer_cnt = 500;
        while (timer_cnt > 0);
        if (cmd < 16) {
          led = 0;
        } else {
          led = 0x5a;
        }
        timer_cnt = 500;
        while (timer_cnt > 0);
      }
    } else {
      led = pattern;
      pattern = (pattern << 1) | (pattern >> 7);
      timer_cnt = 500;
      while (timer_cnt > 0);
    }
  }
}
