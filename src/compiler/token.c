#include "token.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void Locate(char *p);

static int IsIdHead(int c) {
  return isalpha(c) || c == '_';
}

static int IsIdTail(int c) {
  return isalnum(c) || c == '_';
}

struct ReservedMapItem {
  char *name;
  int len;
  enum TokenKind kind;
};

#define ITEM(name, kind) { #name, sizeof(#name)-1, (kind) }
static struct ReservedMapItem reserved_map[] = {
  ITEM(return,        kTokenReturn),
  ITEM(int,           kTokenInt),
  ITEM(if,            kTokenIf),
  ITEM(else,          kTokenElse),
  ITEM(for,           kTokenFor),
  ITEM(char,          kTokenChar),
  ITEM(while,         kTokenWhile),
  ITEM(break,         kTokenBreak),
  ITEM(continue,      kTokenContinue),
  ITEM(void,          kTokenVoid),
  ITEM(asm,           kTokenAsm),
  ITEM(__attribute__, kTokenAttr),
  {NULL, 0, 0},
};
static struct ReservedMapItem operator_map[] = {
  ITEM(++, kTokenInc),
  ITEM(--, kTokenDec),
  ITEM(==, kTokenEq),
  ITEM(!=, kTokenNEq),
  ITEM(&&, kTokenAnd),
  ITEM(||, kTokenOr),
  ITEM(>>, kTokenRShift),
  ITEM(<<, kTokenLShift),
  {NULL, 0, 0},
};
#undef ITEM

static enum TokenKind FindReservedKind(struct ReservedMapItem *map,
                                       char *name, int len) {
  struct ReservedMapItem *it = map;
  for (; it->name; it++) {
    if (it->len == len && strncmp(it->name, name, len) == 0) {
      return it->kind;
    }
  }
  return 0;
}

static char *FindReservedName(struct ReservedMapItem *map,
                              enum TokenKind kind) {
  struct ReservedMapItem *it = map;
  for (; it->name; it++) {
    if (it->kind == kind) {
      return it->name;
    }
  }
  return NULL;
}

static int IsHexDigit(int ch) {
  return isdigit(ch) || strchr("abcdef", tolower(ch));
}

static struct Token *ParseIntegerLiteral(char *src) {
  struct Token *tk;
  char *p = src;

  if (p[0] == '0' && p[1] == 'x' && IsHexDigit(p[2])) {
    p += 2;
    while (IsHexDigit(*(++p)));
    tk = NewToken(kTokenInteger, src, p - src);
    tk->value.as_int = strtol(src + 2, NULL, 16);
  } else if (p[0] == '0') {
    while (isdigit(*(++p)));
    tk = NewToken(kTokenInteger, src, p - src);
    tk->value.as_int = strtol(src, NULL, 8);
  } else {
    while (isdigit(*(++p)));
    tk = NewToken(kTokenInteger, src, p - src);
    tk->value.as_int = strtol(src, NULL, 10);
  }

  return tk;
}

static struct Token *NextToken(char *src) {
  while (1) {
    src += strspn(src, " \t\n");
    if (*src == '\0') {
      return NewToken(kTokenEOF, src, 0);
    } else if (*src != '/') {
      break;
    }

    if (src[1] == '/') {
      char *lf = strchr(src + 2, '\n');
      if (lf == NULL) {
        return NewToken(kTokenEOF, src, 0);
      }
      src = lf + 1;
    } else if (src[1] == '*') {
      char *end = strstr(src + 2, "*/");
      if (end == NULL) {
        return NewToken(kTokenEOF, src, 0);
      }
      src = end + 2;
    } else {
      break;
    }
  }

  char *p = src;

  if (isdigit(*p)) {
    return ParseIntegerLiteral(p);
  }

  if (*p == '\'') {
    int value = 0;
    ++p;
    while (*p != '\'') {
      if (p[0] == '\\') {
        value = (value << 8) + DecodeEscape(p[1]);
        p += 2;
      } else {
        value = (value << 8) + *p;
        ++p;
      }
    }
    struct Token *tk = NewToken(kTokenCharacter, src, p + 1 - src);
    tk->value.as_int = value;
    return tk;
  }

  if (*p == '"') {
    ++p;
    while (*p != '"') {
      if (*p == '\\') {
        p += 2;
      } else {
        ++p;
      }
    }
    return NewToken(kTokenString, src, p + 1 - src);
  }

  if (strchr("+-", p[0]) != NULL && p[1] == '=') {
    return NewToken(kTokenCompAssign + p[0], p, 2);
  }

  enum TokenKind op_kind = FindReservedKind(operator_map, src, 2);
  if (op_kind) {
    return NewToken(op_kind, src, 2);
  }

  if (strchr("+-*/();=<>{}&[]|^~,", *p) != NULL) {
    return NewToken(*p, p, 1);
  }

  if (IsIdHead(*p)) {
    while (IsIdTail(*++p));
    enum TokenKind resv_kind = FindReservedKind(reserved_map, src, p - src);
    if (resv_kind) {
      return NewToken(resv_kind, src, p - src);
    }
    return NewToken(kTokenId, src, p - src);
  }

  fprintf(stderr, "failed to tokenize\n");
  Locate(src);
  exit(1);
}

struct Token *cur_token;

struct Token *NewToken(int kind, char *raw, size_t len) {
  struct Token *tk = calloc(1, sizeof(struct Token));
  tk->kind = kind;
  tk->raw = raw;
  tk->len = len;
  return tk;
}

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
  cur_token = tk->next ? tk->next : tk;
  return tk;
}

struct Token *Expect(int kind) {
  struct Token *tk = Consume(kind);
  if (tk == NULL) {
    char *resv_name = FindReservedName(reserved_map, kind);
    if (resv_name) {
      fprintf(stderr, "'%s'(%d)", resv_name, kind);
    } else if (kind < 128) {
      fprintf(stderr, "'%c'(%d)", kind, kind);
    } else {
      fprintf(stderr, "Tokne(%d)", kind);
    }
    fprintf(stderr, " is expected, but '%.*s'(%d)\n",
            cur_token->len, cur_token->raw, cur_token->kind);
    Locate(cur_token->raw);
    exit(1);
  }
  return tk;
}

char DecodeEscape(char c) {
  switch (c) {
  case '0': return '\0';
  case 'a': return '\a';
  case 'b': return '\b';
  case 't': return '\t';
  case 'n': return '\n';
  case 'v': return '\v';
  case 'f': return '\f';
  case 'r': return '\r';
  default: return c;
  }
}

int DecodeStringLiteral(char *buf, int size, struct Token *tok) {
  if (tok->kind != kTokenString) {
    return -1;
  }

  int bufi = 0;
  for (int i = 1; i < tok->len - 1 && bufi < size; i++, bufi++) {
    if (tok->raw[i] == '\\') {
      i++;
      buf[bufi] = DecodeEscape(tok->raw[i]);
    } else {
      buf[bufi] = tok->raw[i];
    }
  }
  return bufi;
}
