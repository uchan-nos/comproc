#include <ctype.h>
#include <stdint.h>
#include <stdio.h>

int scan_int() {
  int x = 0;
  scanf("%d", &x);
  return x;
}

int scan_char() {
  char c = '\0';
  while (scanf("%c", &c) == 1) {
    if (!isspace(c)) {
      break;
    }
  }
  return c;
}

int main(void) {
  printf("01%02x\n", scan_int());
  switch (scan_char()) {
  case '+':
    printf("03%02x\n", (uint8_t)scan_int());
    break;
  case '-':
    printf("03%02x\n", (uint8_t)-scan_int());
    break;
  }
  printf("0200\n");
}
