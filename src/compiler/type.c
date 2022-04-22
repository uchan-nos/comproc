#include "type.h"

#include <stdio.h>
#include <stdlib.h>

struct Type *NewType(enum TypeKind kind) {
  struct Type *type = malloc(sizeof(struct Type));
  type->kind = kind;
  type->base = NULL;
  return type;
}

size_t SizeofType(struct Type *type) {
  switch (type->kind) {
  case kTypeChar: return 1;
  case kTypeInt: return 2;
  }

  fprintf(stderr, "unknown type: %d\n", type->kind);
  exit(1);
}
