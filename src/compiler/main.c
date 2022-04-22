#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "ast.h"
#include "symbol.h"
#include "token.h"
#include "type.h"

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

struct GenContext {
  struct Symbol *syms;
  uint16_t lvar_offset;
};

void Generate(struct GenContext *ctx, struct Node *node, int lval) {
  switch (node->kind) {
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(ctx, n, 0);
    }
    break;
  case kNodeInteger:
    printf("push %d\n", node->token->value.as_int >> 8);
    printf("push %d\n", node->token->value.as_int & 0xff);
    printf("join\n");
    break;
  case kNodeId:
    {
      struct Symbol *sym = FindSymbol(ctx->syms, node->token);
      if (sym) {
        printf("%s 0x%x\n", lval ? "push" : "ld", sym->offset);
        if (SizeofType(sym->type) == 1) {
          printf("push 0xff\n");
          printf("and\n");
        }
      } else {
        fprintf(stderr, "unknown symbol\n");
        Locate(node->token->raw);
        exit(1);
      }
    }
    break;
  case kNodeAdd:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("add\n");
    break;
  case kNodeSub:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("sub\n");
    break;
  case kNodeMul:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("mul\n");
    break;
  case kNodeAssign:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 1);
    if (lval) {
      printf("sta\n");
    } else {
      printf("std\n");
    }
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(ctx, node->lhs, 0);
      printf("st 0x1\n");
    }
    break;
  case kNodeDefVar:
    {
      struct Symbol *sym = NewSymbol(kSymLVar, node->lhs->token);
      sym->offset = ctx->lvar_offset;
      switch (node->token->kind) {
      case kTokenChar:
        sym->type = NewType(kTypeChar);
        break;
      case kTokenInt:
        sym->type = NewType(kTypeInt);
        break;
      }
      ctx->lvar_offset += 2;
      AppendSymbol(ctx->syms, sym);

      if (node->rhs) {
        Generate(ctx, node->rhs, 0);
        printf("st 0x%x\n", sym->offset);
      }
    }
    break;
  case kNodeLT:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("lt\n");
    break;
  case kNodeIf:
    Generate(ctx, node->cond, 0);
    printf("jz %s\n", node->rhs ? "label_else" : "label_fi");
    Generate(ctx, node->lhs, 0);
    if (node->rhs) {
      printf("jmp label_fi\n");
      printf("label_else:\n");
      Generate(ctx, node->rhs, 0);
    }
    printf("label_fi:\n");
    break;
  case kNodeInc:
  case kNodeDec:
    if (node->lhs) { // 後置インクリメント 'exp ++'
      Generate(ctx, node->lhs, 0);
      printf("push 1\n");
      printf("dup 1\n");
      printf(node->kind == kNodeInc ? "add\n" : "sub\n");
      Generate(ctx, node->lhs, 1);
      printf("sta\n");
      printf("pop\n");
    } else { // 前置インクリメント '++ exp'
      printf("push 1\n");
      Generate(ctx, node->rhs, 0);
      printf(node->kind == kNodeInc ? "add\n" : "sub\n");
      Generate(ctx, node->rhs, 1);
      printf("std\n");
    }
    break;
  case kNodeFor:
    Generate(ctx, node->lhs, 0);
    printf("label_for_cond:\n");
    Generate(ctx, node->cond, 0);
    printf("jz label_for_end\n");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs->next, 0);
    printf("jmp label_for_cond\n");
    printf("label_for_end:\n");
    break;
  case kNodeEq:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("eq\n");
    break;
  case kNodeNEq:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("neq\n");
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

  struct GenContext gen_ctx = { NewSymbol(kSymHead, NULL), 0 };
  Generate(&gen_ctx, ast, 0);

  return 0;
}
