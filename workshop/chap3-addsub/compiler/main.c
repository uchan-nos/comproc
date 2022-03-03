#include <ctype.h>
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
  while (scan_char() == '+') {
    printf("03%02x\n", scan_int());
  }
  printf("0200\n");
}
