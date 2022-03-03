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

int consume_char(int c) {
  int scanned = scan_char();
  if (scanned == c) {
    return c;
  }
  ungetc(scanned, stdin);
  return 0;
}

void Additive();
void Multiplicative();
void Primary();

void Additive() {
  Multiplicative();

  if (consume_char('+')) {
    Additive();
    printf("0300\n");
  } else if (consume_char('-')) {
    Additive();
    printf("0400\n");
  }
}

void Multiplicative() {
  Primary();

  if (consume_char('*')) {
    Multiplicative();
    printf("0500\n");
  }
}

void Primary() {
  int v = scan_int();
  printf("01%02x\n", (uint8_t)v);
}

int main(void) {
  char c;
  Additive();
  printf("0200\n");
}
