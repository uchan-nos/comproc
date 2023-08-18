#pragma once

#include <stdio.h>

#include "token.h"
#include "type.h"

enum NodeKind {
  // 式（値をスタックに積むもの）
  kNodeInteger,
  kNodeId,
  kNodeAdd,
  kNodeSub,
  kNodeMul,
  kNodeAssign,
  kNodeLT, // <
  kNodeInc,
  kNodeDec,
  kNodeEq,
  kNodeNEq,
  kNodeRef,   // & exp
  kNodeDeref, // * exp
  kNodeLAnd,  // &&
  kNodeLOr,   // ||
  kNodeString,// string literal
  kNodeAnd,   // &
  kNodeXor,   // ^
  kNodeOr,    // |
  kNodeNot,   // ~
  kNodeRShift,// >>
  kNodeLShift,// <<
  kNodeCall,
  kNodeExprEnd,
  // 式以外（値をスタックに積まないもの）
  kNodeDefFunc,
  kNodeBlock,
  kNodeReturn,
  kNodeDefVar,
  kNodeIf,
  kNodeFor,
  kNodeWhile,
  kNodeBreak,
  kNodeContinue,
  kNodeTypeSpec,
  kNodePList,
};

struct Node {
  enum NodeKind kind;  // ノードの種類
  int index;           // ノードのインデックス
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
  // kNodeDefFunc 戻り値型  ブロック  仮引数
  // kNodeCall    関数名    引数      NULL
  // kNodePList   変数名    NULL      NULL
  struct Node *lhs, *rhs, *cond;
};

struct Node *NewNode(enum NodeKind kind, struct Token *token);
struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs);
struct Node *Program();
struct Node *FunctionDefinition();
struct Node *Block();
struct Node *Declaration();
struct Node *Statement();
struct Node *Expression();
struct Node *Assignment();
struct Node *LogicalOr();
struct Node *LogicalAnd();
struct Node *BitwiseOr();
struct Node *BitwiseXor();
struct Node *BitwiseAnd();
struct Node *Equality();
struct Node *Relational();
struct Node *BitwiseShift();
struct Node *Additive();
struct Node *Multiplicative();
struct Node *Unary();
struct Node *Postfix();
struct Node *Primary();

struct Node *TypeSpec();
struct Node *ParameterList();

void PrintNode(FILE *out, struct Node *n, int indent, const char *key);
