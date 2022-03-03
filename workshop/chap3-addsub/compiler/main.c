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
  char c;
  printf("01%02x\n", scan_int());
  while ((c = scan_char()) != '\0') {
    if (c == '+') {
      printf("03%02x\n", (uint8_t)scan_int());
    } else if (c == '-') {
      printf("03%02x\n", (uint8_t)-scan_int());
    }
  }
  printf("0200\n");
}
