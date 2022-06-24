#include "ast.h"

#include <stdio.h>
#include <stdlib.h>

#include "token.h"

void Locate(char *p);

struct Node *NewNode(enum NodeKind kind, struct Token *token) {
  struct Node *n = malloc(sizeof(struct Node));
  n->kind = kind;
  n->token = token;
  n->next = n->lhs = n->rhs = n->cond = NULL;
  n->type = NULL;
  return n;
}

struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs) {
  struct Node *n = NewNode(kind, op);
  n->lhs = lhs;
  n->rhs = rhs;
  return n;
}

struct Node *Program() {
  struct Node *head = FunctionDefinition();
  struct Node *n = head;
  while (n) {
    n->next = FunctionDefinition();
    n = n->next;
  }
  return head;
}

struct Node *FunctionDefinition() {
  if (Consume(kTokenInt) == NULL) {
    return NULL;
  }

  struct Token *func_name = Expect(kTokenId);
  Expect('(');
  Expect(')');
  struct Node *body = Block();

  struct Node *func_def = NewNode(kNodeDefFunc, func_name);
  func_def->rhs = body;
  return func_def;
}

struct Node *Block() {
  struct Token *brace = Consume('{');
  if (brace == NULL) {
    return NULL;
  }

  struct Node *block = NewNode(kNodeBlock, brace);

  struct Node *node = block;
  while (Consume('}') == NULL) {
    if ((node->next = Declaration())) {
    } else if ((node->next = Statement())) {
    } else {
      fprintf(stderr, "either declaration or statement is expected\n");
      Locate(cur_token->raw);
      exit(1);
    }

    node = node->next;
  }

  return block;
}

struct Node *Declaration() {
  struct Token *token;
  struct Type *type = NULL;

  if ((token = Consume(kTokenInt))) {
    type = NewType(kTypeInt);
  } else if ((token = Consume(kTokenChar))) {
    type = NewType(kTypeChar);
  }

  if (!type) {
    return NULL;
  }

  struct Node *def = NewNode(kNodeDefVar, token);

  if (Consume('*')) {
    struct Type *t = NewType(kTypePtr);
    t->base = type;
    type = t;
  }

  struct Token *id = Expect(kTokenId);
  if (id->len != 1) {
    fprintf(stderr, "variable name must be one character\n");
    Locate(id->raw);
    exit(1);
  }
  def->lhs = NewNode(kNodeId, id);

  if (Consume('[')) {
    struct Token *len = Expect(kTokenInteger);
    Expect(']');
    struct Type *t = NewType(kTypeArray);
    t->len = len->value.as_int;
    t->base = type;
    type = t;
  }

  def->type = type;

  if (Consume('=')) {
    def->rhs = Expression();
  }
  Expect(';');

  return def;
}

struct Node *Statement() {
  struct Token *token;

  if ((token = Consume(kTokenReturn))) {
    struct Node *ret = NewNode(kNodeReturn, token);
    ret->lhs = Expression();
    Expect(';');
    return ret;
  }

  if ((token = Consume(kTokenIf))) {
    struct Node *if_ = NewNode(kNodeIf, token);
    Expect('(');
    if_->cond = Expression();
    Expect(')');
    if_->lhs = Block();

    if ((token = Consume(kTokenElse))) {
      if_->rhs = Block();
    }

    return if_;
  }

  if ((token = Consume(kTokenFor))) {
    struct Node *for_ = NewNode(kNodeFor, token);
    Expect('(');
    for_->lhs = Expression();
    Expect(';');
    for_->cond = Expression();
    Expect(';');
    for_->lhs->next = Expression();
    Expect(')');
    for_->rhs = Block();

    return for_;
  }

  if ((token = Consume(kTokenWhile))) {
    struct Node *while_ = NewNode(kNodeWhile, token);
    Expect('(');
    while_->cond = Expression();
    Expect(')');
    while_->rhs = Block();

    return while_;
  }

  if ((token = Consume(kTokenBreak))) {
    Expect(';');
    return NewNode(kNodeBreak, token);
  }

  if ((token = Consume(kTokenContinue))) {
    Expect(';');
    return NewNode(kNodeContinue, token);
  }

  struct Node *e = Expression();
  Expect(';');

  return e;
}

struct Node *Expression() {
  return Assignment();
}

struct Node *Assignment() {
  struct Node *node = LogicalOr();

  struct Token *op;
  if ((op = Consume('='))) {
    node = NewNodeBinOp(kNodeAssign, op, node, Assignment());
  } else if ((op = Consume(kTokenCompAssign + '+'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeAdd, op, node, Assignment()));
  } else if ((op = Consume(kTokenCompAssign + '-'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeSub, op, node, Assignment()));
  }

  return node;
}

struct Node *LogicalOr() {
  struct Node *node = LogicalAnd();

  struct Token *op;
  if ((op = Consume(kTokenOr))) {
    node = NewNodeBinOp(kNodeLOr, op, node, LogicalOr());
  }

  return node;
}

struct Node *LogicalAnd() {
  struct Node *node = BitwiseOr();

  struct Token *op;
  if ((op = Consume(kTokenAnd))) {
    node = NewNodeBinOp(kNodeLAnd, op, node, LogicalAnd());
  }

  return node;
}

struct Node *BitwiseOr() {
  struct Node *node = BitwiseXor();

  struct Token *op;
  if ((op = Consume('|'))) {
    node = NewNodeBinOp(kNodeOr, op, node, BitwiseOr());
  }

  return node;
}

struct Node *BitwiseXor() {
  struct Node *node = BitwiseAnd();

  struct Token *op;
  if ((op = Consume('^'))) {
    node = NewNodeBinOp(kNodeXor, op, node, BitwiseXor());
  }

  return node;
}

struct Node *BitwiseAnd() {
  struct Node *node = Equality();

  struct Token *op;
  if ((op = Consume('&'))) {
    node = NewNodeBinOp(kNodeAnd, op, node, BitwiseAnd());
  }

  return node;
}

struct Node *Equality() {
  struct Node *node = Relational();

  struct Token *op;
  if ((op = Consume(kTokenEq))) {
    node = NewNodeBinOp(kNodeEq, op, node, Equality());
  } else if ((op = Consume(kTokenNEq))) {
    node = NewNodeBinOp(kNodeNEq, op, node, Equality());
  }

  return node;
}

struct Node *Relational() {
  struct Node *node = BitwiseShift();

  struct Token *op;
  if ((op = Consume('<'))) {
    node = NewNodeBinOp(kNodeLT, op, node, Relational());
  } else if ((op = Consume('>'))) {
    node = NewNodeBinOp(kNodeLT, op, Relational(), node);
  }

  return node;
}

struct Node *BitwiseShift() {
  struct Node *node = Additive();

  struct Token *op;
  if ((op = Consume(kTokenRShift))) {
    node = NewNodeBinOp(kNodeRShift, op, node, BitwiseShift());
  } else if ((op = Consume(kTokenLShift))) {
    node = NewNodeBinOp(kNodeLShift, op, node, BitwiseShift());
  }

  return node;
}

struct Node *Additive() {
  struct Node *node = Multiplicative();

  struct Token *op;
  if ((op = Consume('+'))) {
    node = NewNodeBinOp(kNodeAdd, op, node, Additive());
  } else if ((op = Consume('-'))) {
    node = NewNodeBinOp(kNodeSub, op, node, Additive());
  }

  return node;
}

struct Node *Multiplicative() {
  struct Node *node = Unary();

  struct Token *op;
  if ((op = Consume('*'))) {
    node = NewNodeBinOp(kNodeMul, op, node, Multiplicative());
  }

  return node;
}

struct Node *Unary() {
  struct Node *node;

  struct Token *op;
  if ((op = Consume(kTokenInc))) {
    node = NewNodeBinOp(kNodeInc, op, NULL, Unary());
  } else if ((op = Consume(kTokenDec))) {
    node = NewNodeBinOp(kNodeDec, op, NULL, Unary());
  } else if ((op = Consume('&'))) {
    node = NewNodeBinOp(kNodeRef, op, NULL, Unary());
  } else if ((op = Consume('*'))) {
    node = NewNodeBinOp(kNodeDeref, op, NULL, Unary());
  } else if ((op = Consume('-'))) {
    struct Token *zero_tk = NewToken(kTokenInteger, NULL, 0);
    zero_tk->value.as_int = 0;
    struct Node *zero = NewNode(kNodeInteger, zero_tk);
    node = NewNodeBinOp(kNodeSub, op, zero, Unary());
  } else if ((op = Consume('~'))) {
    node = NewNodeBinOp(kNodeNot, op, NULL, Unary());
  } else {
    node = Postfix();
  }

  return node;
}

struct Node *Postfix() {
  struct Node *node = Primary();

  struct Token *op;
  if ((op = Consume(kTokenInc))) {
    node = NewNodeBinOp(kNodeInc, op, node, NULL);
  } else if ((op = Consume(kTokenDec))) {
    node = NewNodeBinOp(kNodeDec, op, node, NULL);
  } else if ((op = Consume('['))) {
    node = NewNodeBinOp(kNodeDeref, op, NULL,
                        NewNodeBinOp(kNodeAdd, op, node, Expression()));
    Expect(']');
  } else if ((op = Consume('('))) {
    node = NewNodeBinOp(kNodeCall, op, node, NULL);
    Expect(')');
  }

  return node;
}

struct Node *Primary() {
  struct Node *node = NULL;
  struct Token *tk;
  if ((tk = Consume('('))) {
    node = Expression();
    Expect(')');
  } else if ((tk = Consume(kTokenInteger))) {
    node = NewNode(kNodeInteger, tk);
    node->type = NewType(kTypeInt);
  } else if ((tk = Consume(kTokenCharacter))) {
    node = NewNode(kNodeInteger, tk);
    node->type = NewType(kTypeInt);
  } else if ((tk = Consume(kTokenString))) {
    node = NewNode(kNodeString, tk);
    node->type = NewType(kTypePtr);
    node->type->base = NewType(kTypeChar);
  } else if ((tk = Consume(kTokenId))) {
    node = NewNode(kNodeId, tk);
  }

  if (!node) {
    fprintf(stderr, "a primary expression is expected.\n");
    Locate(cur_token->raw);
    exit(1);
  }

  return node;
}
