#pragma once

#include "token.h"

enum NodeKind {
  kNodeBlock,
  kNodeInteger,
  kNodeId,
  kNodeAdd,
  kNodeSub,
  kNodeMul,
  kNodeAssign,
  kNodeReturn,
  kNodeDefVar,
};

struct Node {
  enum NodeKind kind;  // ノードの種類
  struct Token *token; // ノードを代表するトークン
  struct Node *next;   // 線形リスト

  // 用途         lhs     rhs
  // ---------------------------
  // 2 項演算     左辺    右辺
  // kNodeReturn  返却値  NULL
  // kNodeDefVar  変数名  初期値
  struct Node *lhs, *rhs;
};

struct Node *NewNode(enum NodeKind kind, struct Token *token);
struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs);
