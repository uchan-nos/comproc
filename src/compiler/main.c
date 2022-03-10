#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "token.h"


void Additive();
void Multiplicative();
void Primary();

void Additive() {
  Multiplicative();

  if (Consume('+')) {
    Additive();
    printf("0300\n");
  } else if (Consume('-')) {
    Additive();
    printf("0400\n");
  }
}

void Multiplicative() {
  Primary();

  if (Consume('*')) {
    Multiplicative();
    printf("0500\n");
  }
}

void Primary() {
  struct Token *tk = Expect(kTokenInteger);
  printf("01%02x\n", (uint8_t)tk->value.as_int);
}

int main(void) {
  char *src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, stdin);
  src[src_len] = '\0';

  Tokenize(src);
  Expect(kTokenReturn);
  Additive();
  Expect(';');
  Expect(kTokenEOF);
  printf("0200\n");
}
