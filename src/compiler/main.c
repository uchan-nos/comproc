#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ast.h"
#include "token.h"

struct Node *BlockItemList();
struct Node *Expression();
struct Node *Assignment();
struct Node *Additive();
struct Node *Multiplicative();
struct Node *Primary();

struct Node *BlockItemList() {
  struct Node *block = NewNode(kNodeBlock, NULL);
  struct Token *token;

  struct Node *node = block;
  while (Consume(kTokenEOF) == NULL) {
    if ((token = Consume(kTokenInt))) {
      struct Node *def = NewNode(kNodeDefVar, token);

      struct Token *id = Expect(kTokenId);
      if (id->len != 1) {
        fprintf(stderr, "variable name must be one character: '%.*s'\n",
                id->len, id->raw);
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
  struct Node *node = Additive();

  struct Token *op;
  if ((op = Consume('='))) {
    node = NewNodeBinOp(kNodeAssign, op, node, Assignment());
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

void Generate(struct Node *node, int lval) {
  switch (node->kind) {
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(n, 0);
    }
    break;
  case kNodeInteger:
    printf("01%02x\n", (uint8_t)node->token->value.as_int);
    break;
  case kNodeId:
    printf("%02x%02x\n", lval ? 1 : 7, node->token->raw[0]);
    break;
  case kNodeAdd:
    Generate(node->lhs, 0);
    Generate(node->rhs, 0);
    printf("0300\n");
    break;
  case kNodeSub:
    Generate(node->lhs, 0);
    Generate(node->rhs, 0);
    printf("0400\n");
    break;
  case kNodeMul:
    Generate(node->lhs, 0);
    Generate(node->rhs, 0);
    printf("0500\n");
    break;
  case kNodeAssign:
    Generate(node->lhs, 1);
    Generate(node->rhs, 0);
    if (lval) {
      printf("0601\n");
    } else {
      printf("0600\n");
    }
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(node->lhs, 0);
      printf("0200\n");
    }
    break;
  case kNodeDefVar:
    if (node->rhs) {
      Generate(node->rhs, 0);
      printf("06%02x\n", (uint8_t)node->lhs->token->raw[0]);
    }
    break;
  }
}

int main(void) {
  char *src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, stdin);
  src[src_len] = '\0';

  Tokenize(src);
  struct Node *ast = BlockItemList();
  Expect(kTokenEOF);
  Generate(ast, 0);

  return 0;
}
