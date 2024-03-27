int tim_count __attribute__((at(0x02)));
int uart_data __attribute__((at(0x06)));
int uart_flag __attribute__((at(0x08)));

int recv_cnt;
int recv_last;

void _ISR() {
  if (uart_flag & 1) {
    recv_last = uart_data;
    recv_cnt++;
  }
}

int main() {
  recv_cnt = 0;
  asm("push _ISR\n\t"
      "isr");
  uart_flag = 2; // 受信割り込みを有効化
  while (recv_cnt < 8);
  return recv_cnt;
}
