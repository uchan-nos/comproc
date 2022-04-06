#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ast.h"
#include "token.h"

char *src;
void Locate(char *p) {
  char *start = p, *end = p;

  while (src < start && *(start - 1) != '\n') {
    start--;
  }

  while (*end && *end != '\n') {
    end++;
  }

  fprintf(stderr, "%.*s\n", (int)(end - start), start);
  fprintf(stderr, "%*s\n", (int)(p - start + 1), "^");
}

void Generate(struct Node *node, int lval) {
  switch (node->kind) {
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(n, 0);
    }
    break;
  case kNodeInteger:
    printf("push %d\n", node->token->value.as_int);
    break;
  case kNodeId:
    printf("%s 0x%x\n", lval ? "push" : "ld", (uint8_t)node->token->raw[0]);
    break;
  case kNodeAdd:
    Generate(node->rhs, 0);
    Generate(node->lhs, 0);
    printf("add\n");
    break;
  case kNodeSub:
    Generate(node->rhs, 0);
    Generate(node->lhs, 0);
    printf("sub\n");
    break;
  case kNodeMul:
    Generate(node->rhs, 0);
    Generate(node->lhs, 0);
    printf("mul\n");
    break;
  case kNodeAssign:
    Generate(node->rhs, 0);
    Generate(node->lhs, 1);
    if (lval) {
      printf("sta\n");
    } else {
      printf("std\n");
    }
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(node->lhs, 0);
      printf("st 0x1\n");
    }
    break;
  case kNodeDefVar:
    if (node->rhs) {
      Generate(node->rhs, 0);
      printf("st 0x%x\n", (uint8_t)node->lhs->token->raw[0]);
    }
    break;
  case kNodeLT:
    Generate(node->rhs, 0);
    Generate(node->lhs, 0);
    printf("lt\n");
    break;
  case kNodeIf:
    Generate(node->cond, 0);
    printf("jz label_else\n");
    Generate(node->lhs, 0);
    printf("jmp label_fi\n");
    printf("label_else:\n");
    Generate(node->rhs, 0);
    printf("label_fi:\n");
    break;
  }
}

int main(void) {
  src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, stdin);
  src[src_len] = '\0';

  Tokenize(src);
  struct Node *ast = Block();
  Expect(kTokenEOF);
  Generate(ast, 0);

  return 0;
}
