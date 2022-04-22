#pragma once

#include <stddef.h>

enum TypeKind {
  kTypeChar,
  kTypeInt,
  kTypePtr,
};

struct Type {
  enum TypeKind kind;
  struct Type *base;
};

struct Type *NewType(enum TypeKind kind);
size_t SizeofType(struct Type *type);
