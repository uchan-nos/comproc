#include "token.h"

#include <ctype.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static struct Token *NewToken(int kind, char *raw, size_t len) {
  struct Token *tk = calloc(1, sizeof(struct Token));
  tk->kind = kind;
  tk->raw = raw;
  tk->len = len;
  return tk;
}

static struct Token *NextToken(char *src) {
  src += strspn(src, " \t\n");
  if (*src == '\0') {
    return NewToken(kTokenEOF, src, 0);
  }

  char *p = src;

  if (isdigit(*p)) {
    struct Token *tk = NewToken(kTokenInt, src, 0);
    while (isdigit(*(++p)));
    tk->len = p - src;
    tk->value.as_int = strtol(src, NULL, 10);
    return tk;
  }

  if (strchr("+-*/()", *p) != NULL) {
    return NewToken(*p, p, 1);
  }

  return NULL;
}

struct Token *cur_token;

void Tokenize(char *src) {
  struct Token *tk = cur_token = NextToken(src);
  while (tk && tk->kind != kTokenEOF) {
    tk->next = NextToken(tk->raw + tk->len);
    tk = tk->next;
  }
}

struct Token *Consume(int kind) {
  struct Token *tk = cur_token;
  if (tk->kind != kind) {
    return NULL;
  }
  cur_token = tk->next;
  return tk;
}

struct Token *Expect(int kind) {
  struct Token *tk = Consume(kind);
  if (tk == NULL) {
    fprintf(stderr, "Token(%d) is expected, but '%.*s'(%d)\n",
            tk->kind, tk->len, tk->raw, tk->kind);
    exit(1);
  }
  return tk;
}

