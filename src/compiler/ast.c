#include "ast.h"

#include <stdio.h>
#include <stdlib.h>

void Locate(char *p);

struct Node *NewNode(enum NodeKind kind, struct Token *token) {
  struct Node *n = malloc(sizeof(struct Node));
  n->kind = kind;
  n->token = token;
  n->next = n->lhs = n->rhs = n->cond = NULL;
  return n;
}

struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs) {
  struct Node *n = NewNode(kind, op);
  n->lhs = lhs;
  n->rhs = rhs;
  return n;
}

struct Node *Block() {
  struct Token *brace = Consume('{');
  if (brace == NULL) {
    return NULL;
  }

  struct Node *block = NewNode(kNodeBlock, brace);
  struct Token *token;

  struct Node *node = block;
  while (Consume('}') == NULL) {
    if ((token = Consume(kTokenInt))) {
      struct Node *def = NewNode(kNodeDefVar, token);

      struct Token *id = Expect(kTokenId);
      if (id->len != 1) {
        fprintf(stderr, "variable name must be one character\n");
        Locate(id->raw);
        exit(1);
      }
      def->lhs = NewNode(kNodeId, id);

      if (Consume('=')) {
        def->rhs = Expression();
      }
      Expect(';');

      node->next = def;
    } else if ((token = Consume(kTokenReturn))) {
      struct Node *ret = NewNode(kNodeReturn, token);
      ret->lhs = Expression();
      Expect(';');

      node->next = ret;
    } else if ((token = Consume(kTokenIf))) {
      struct Node *if_ = NewNode(kNodeIf, token);
      Expect('(');
      if_->cond = Expression();
      Expect(')');
      if_->lhs = Block();

      node->next = if_;
    } else {
      node->next = Expression();
      Expect(';');
    }

    node = node->next;
  }

  return block;
}

struct Node *Expression() {
  return Assignment();
}

struct Node *Assignment() {
  struct Node *node = Relational();

  struct Token *op;
  if ((op = Consume('='))) {
    node = NewNodeBinOp(kNodeAssign, op, node, Assignment());
  }

  return node;
}

struct Node *Relational() {
  struct Node *node = Additive();

  struct Token *op;
  if ((op = Consume('<'))) {
    node = NewNodeBinOp(kNodeLT, op, node, Relational());
  } else if ((op = Consume('>'))) {
    node = NewNodeBinOp(kNodeLT, op, Relational(), node);
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
  struct Node *node = Primary();

  struct Token *op;
  if ((op = Consume('*'))) {
    node = NewNodeBinOp(kNodeMul, op, node, Multiplicative());
  }

  return node;
}

struct Node *Primary() {
  struct Node *node;
  struct Token *tk;
  if ((tk = Consume('('))) {
    node = Expression();
    Expect(')');
  } else if ((tk = Consume(kTokenInteger))) {
    node = NewNode(kNodeInteger, tk);
  } else if ((tk = Consume(kTokenId))) {
    node = NewNode(kNodeId, tk);
  }

  return node;
}
