#include "mmio.h"

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
  __builtin_set_isr(_ISR);
  uart_flag = 2; // 受信割り込みを有効化
  while (recv_cnt < 8);
  return recv_cnt;
}
