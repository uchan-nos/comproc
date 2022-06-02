#pragma once

#include "token.h"
#include "type.h"

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
  kNodeLT, // <
  kNodeIf,
  kNodeInc,
  kNodeDec,
  kNodeFor,
  kNodeWhile,
  kNodeBreak,
  kNodeEq,
  kNodeNEq,
  kNodeRef,   // & exp
  kNodeDeref, // * exp
  kNodeLAnd,  // &&
  kNodeString,// string literal
  kNodeLOr,   // ||
};

struct Node {
  enum NodeKind kind;  // ノードの種類
  struct Token *token; // ノードを代表するトークン
  struct Node *next;   // 線形リスト
  struct Type *type;   // ノードの型

  // 用途         lhs       rhs       cond      備考
  // ------------------------------------------------------
  // 2 項演算     左辺      右辺      NULL
  // kNodeReturn  返却値    NULL      NULL
  // kNodeDefVar  変数名    初期値    NULL
  // kNodeIf      then      else      条件式
  // kNodeFor     初期化式  ブロック  条件式    lhs->next は更新式
  // kNodeWhile   NULL      ブロック  条件式
  struct Node *lhs, *rhs, *cond;
};

struct Node *NewNode(enum NodeKind kind, struct Token *token);
struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs);
struct Node *Block();
struct Node *Declaration();
struct Node *Statement();
struct Node *Expression();
struct Node *Assignment();
struct Node *LogicalOr();
struct Node *LogicalAnd();
struct Node *Equality();
struct Node *Relational();
struct Node *Additive();
struct Node *Multiplicative();
struct Node *Unary();
struct Node *Postfix();
struct Node *Primary();

struct Node *TypeSpec();
