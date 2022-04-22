#pragma once

#include <stddef.h>

enum TypeKind {
  kTypeChar,
  kTypeInt,
};

struct Type {
  enum TypeKind kind;
};

struct Type *NewType(enum TypeKind kind);
size_t SizeofType(struct Type *type);
