#pragma once

#include <stdint.h>

#include "token.h"

enum SymbolKind {
  kSymHead, // 線形リストのヘッドを表す特殊な種別
  kSymLVar, // ローカル変数
};

struct Type;

struct Symbol {
  enum SymbolKind kind;
  struct Token *name;
  struct Symbol *next;

  uint16_t offset;
  struct Type *type;
};

struct Symbol *NewSymbol(enum SymbolKind kind, struct Token *name);
struct Symbol *AppendSymbol(struct Symbol *head, struct Symbol *sym);
struct Symbol *FindSymbol(struct Symbol *head, struct Token *name);
