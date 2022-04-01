#include "ast.h"

#include <stdlib.h>

struct Node *NewNode(enum NodeKind kind, struct Token *token) {
  struct Node *n = malloc(sizeof(struct Node));
  n->kind = kind;
  n->token = token;
  n->next = n->lhs = n->rhs = NULL;
  return n;
}

struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs) {
  struct Node *n = NewNode(kind, op);
  n->lhs = lhs;
  n->rhs = rhs;
  return n;
}
