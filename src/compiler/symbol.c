#include "symbol.h"

#include <stdlib.h>
#include <string.h>

void Locate(char *p);

struct Symbol *NewSymbol(enum SymbolKind kind, struct Token *name) {
  struct Symbol *s = malloc(sizeof(struct Symbol));
  s->kind = kind;
  s->name = name;
  s->next = NULL;
  s->offset = 0;

  return s;
}

struct Symbol *AppendSymbol(struct Symbol *head, struct Symbol *sym) {
  for (; head->next; head = head->next);
  head->next = sym;
  return sym;
}

struct Symbol *FindSymbol(struct Symbol *head, struct Token *name) {
  for (; head; head = head->next) {
    if (head->kind != kSymHead &&
        head->name->len == name->len &&
        strncmp(head->name->raw, name->raw, name->len) == 0) {
      return head;
    }
  }
  return NULL;
}
