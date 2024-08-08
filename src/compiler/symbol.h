#pragma once

#include <stdint.h>

#include "token.h"

enum SymbolKind {
  kSymHead, // 線形リストのヘッドを表す特殊な種別
  kSymGVar, // グローバル変数
  kSymLVar, // ローカル変数
  kSymFunc, // 関数
};

struct Type;
struct Node;

struct Symbol {
  enum SymbolKind kind;
  struct Token *name;
  struct Symbol *next;
  struct Node *def;

  uint16_t offset;
  struct Type *type;
};

struct Symbol *NewSymbol(enum SymbolKind kind, struct Token *name);
struct Symbol *AppendSymbol(struct Symbol *head, struct Symbol *sym);
struct Symbol *FindSymbolLocal(struct Symbol *head, struct Token *name);

struct Scope {
  struct Scope *parent;
  struct Symbol *syms;
  int frame_size; // このスコープのローカル変数領域のサイズ
};

// 新しくスコープを生成し、生成したスコープを返す
struct Scope *EnterScope(struct Scope *current);

// 現在のスコープを抜け、1 段上のスコープを返す
struct Scope *LeaveScope(struct Scope *current);

// 現在のスコープにおいてシンボルを検索する
struct Symbol *FindSymbol(struct Scope *scope, struct Token *name);

struct Scope *NewGlobalScope();
