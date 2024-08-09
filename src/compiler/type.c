#include "type.h"

#include <stdlib.h>

struct Type *NewType(enum TypeKind kind) {
  struct Type *type = malloc(sizeof(struct Type));
  type->kind = kind;
  type->base = NULL;
  type->len = 0;
  type->attr = 0;
  return type;
}

size_t SizeofType(struct Type *type) {
  switch (type->kind) {
  case kTypeChar: return 1;
  case kTypeInt: return 2;
  case kTypePtr: return 2;
  case kTypeArray: return type->len * SizeofType(type->base);
  case kTypeVoid: return 0;
  }

  fprintf(stderr, "unknown type: %d\n", type->kind);
  exit(1);
}

void PrintType(FILE *out, struct Type *type) {
  switch (type->kind) {
  case kTypeChar:
    fprintf(out, (type->attr & TYPE_ATTR_SIGNED) ? "signed char" : "char");
    break;
  case kTypeInt:
    fprintf(out, (type->attr & TYPE_ATTR_SIGNED) ? "int" : "unsigned int");
    break;
  case kTypePtr:
    fprintf(out, "*");
    PrintType(out, type->base);
    break;
  case kTypeArray:
    PrintType(out, type->base);
    fprintf(out, "[%d]", type->len);
    break;
  case kTypeVoid:
    fprintf(out, "void");
    break;
  }
}
