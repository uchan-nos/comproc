#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "token.h"

void BlockItemList();
void Additive();
void Multiplicative();
void Primary();

void BlockItemList() {
  while (1) {
    if (Consume(kTokenInt)) {
      struct Token *id = Expect(kTokenId);
      if (id->len != 1) {
        fprintf(stderr, "variable name must be one character: '%.*s'\n",
                id->len, id->raw);
        exit(1);
      }
      uint8_t addr = id->raw[0];
      if (Consume('=')) {
        Additive();
        printf("06%02x\n", addr);
      }
      Expect(';');
    } else if (Consume(kTokenReturn)) {
      Additive();
      Expect(';');
      printf("0200\n");
    } else {
      break;
    }
  }
}

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
  struct Token *tk;
  if ((tk = Consume('('))) {
    Additive();
    Expect(')');
  } else if ((tk = Consume(kTokenInteger))) {
    printf("01%02x\n", (uint8_t)tk->value.as_int);
  } else if ((tk = Consume(kTokenId))) {
    printf("07%02x\n", tk->raw[0]);
  }
}

int main(void) {
  char *src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, stdin);
  src[src_len] = '\0';

  Tokenize(src);
  BlockItemList();
  Expect(kTokenEOF);
}
