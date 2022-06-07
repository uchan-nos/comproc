#include <assert.h>
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

struct JumpLabels {
  int lbreak;
  int lcontinue;
};

struct GenContext {
  struct Symbol *syms;
  uint16_t lvar_offset;
  int num_label;
  int num_strings;
  struct Token *strings[4];
  struct JumpLabels jump_labels;
};

int GenLabel(struct GenContext *ctx) {
  return ctx->num_label++;
}

void Generate(struct GenContext *ctx, struct Node *node, int lval) {
  switch (node->kind) {
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(ctx, n, 0);
    }
    break;
  case kNodeInteger:
    if ((node->token->value.as_int >> 15) == 0) {
      printf("push %d\n", node->token->value.as_int);
    } else {
      printf("push %d\n", node->token->value.as_int >> 8);
      printf("push %d\n", node->token->value.as_int & 0xff);
      printf("join\n");
    }
    break;
  case kNodeId:
    {
      struct Symbol *sym = FindSymbol(ctx->syms, node->token);
      if (sym) {
        assert(sym->type);
        node->type = sym->type;
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
    node->type = node->lhs->type;
    break;
  case kNodeSub:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("sub\n");
    node->type = node->lhs->type;
    break;
  case kNodeMul:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf("mul\n");
    node->type = node->lhs->type;
    break;
  case kNodeAssign:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 1);
    if (lval) {
      printf("sta\n");
    } else {
      printf("std\n");
    }
    node->type = node->lhs->type;
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(ctx, node->lhs, 0);
      printf("st 0x2\n");
    }
    break;
  case kNodeDefVar:
    {
      struct Symbol *sym = NewSymbol(kSymLVar, node->lhs->token);
      sym->offset = ctx->lvar_offset;

      assert(node->type);
      sym->type = node->type;

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
    {
      int label_else = node->rhs ? GenLabel(ctx) : -1;
      int label_end = GenLabel(ctx);
      Generate(ctx, node->cond, 0);
      printf("jz L_%d\n", node->rhs ? label_else : label_end);
      Generate(ctx, node->lhs, 0);
      if (node->rhs) {
        printf("jmp L_%d\n", label_end);
        printf("L_%d:\n", label_else);
        Generate(ctx, node->rhs, 0);
      }
      printf("L_%d:\n", label_end);
    }
    break;
  case kNodeInc:
  case kNodeDec:
    if (node->lhs) { // 後置インクリメント 'exp ++'
      Generate(ctx, node->lhs, 0);
      printf("push 1\n");
      printf("dup 1\n");
      printf(node->kind == kNodeInc ? "add\n" : "sub\n");
      Generate(ctx, node->lhs, 1);
      printf("sta.%d\n", (int)SizeofType(node->lhs->type));
      printf("pop\n");
    } else { // 前置インクリメント '++ exp'
      printf("push 1\n");
      Generate(ctx, node->rhs, 0);
      printf(node->kind == kNodeInc ? "add\n" : "sub\n");
      Generate(ctx, node->rhs, 1);
      printf("std.%d\n", (int)SizeofType(node->rhs->type));
    }
    break;
  case kNodeFor:
    {
      int label_cond = GenLabel(ctx);
      int label_end = GenLabel(ctx);
      int label_next = GenLabel(ctx);

      struct JumpLabels old_labels = ctx->jump_labels;
      ctx->jump_labels.lbreak = label_end;
      ctx->jump_labels.lcontinue = label_next;

      Generate(ctx, node->lhs, 0);
      printf("L_%d:\n", label_cond);
      Generate(ctx, node->cond, 0);
      printf("jz L_%d\n", label_end);
      Generate(ctx, node->rhs, 0);
      printf("L_%d:\n", label_next);
      Generate(ctx, node->lhs->next, 0);
      printf("jmp L_%d\n", label_cond);
      printf("L_%d:\n", label_end);

      ctx->jump_labels = old_labels;
    }
    break;
  case kNodeWhile:
    {
      int label_cond = GenLabel(ctx);
      int label_end = GenLabel(ctx);

      struct JumpLabels old_labels = ctx->jump_labels;
      ctx->jump_labels.lbreak = label_end;
      ctx->jump_labels.lcontinue = label_cond;

      printf("L_%d:\n", label_cond);
      Generate(ctx, node->cond, 0);
      printf("jz L_%d\n", label_end);
      Generate(ctx, node->rhs, 0);
      printf("jmp L_%d\n", label_cond);
      printf("L_%d:\n", label_end);

      ctx->jump_labels = old_labels;
    }
    break;
  case kNodeBreak:
    printf("jmp L_%d\n", ctx->jump_labels.lbreak);
    break;
  case kNodeContinue:
    printf("jmp L_%d\n", ctx->jump_labels.lcontinue);
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
  case kNodeRef:
    Generate(ctx, node->rhs, 1);
    break;
  case kNodeDeref:
    if (lval) {
      Generate(ctx, node->rhs, 0);
    } else {
      Generate(ctx, node->rhs, 0);
      if (SizeofType(node->rhs->type->base) == 1) {
        printf("ldd.1\n");
      } else {
        printf("ldd\n");
      }
    }
    assert(node->rhs->type->base);
    node->type = node->rhs->type->base;
    break;
  case kNodeLAnd:
    {
      int label_false = GenLabel(ctx);
      int label_end = GenLabel(ctx);
      Generate(ctx, node->lhs, 0);
      printf("jz L_%d\n", label_false);
      Generate(ctx, node->rhs, 0);
      printf("jz L_%d\n", label_false);
      printf("push 1\n");
      printf("jmp L_%d\n", label_end);
      printf("L_%d:\n", label_false);
      printf("push 0\n");
      printf("L_%d:\n", label_end);
    }
    break;
  case kNodeLOr:
    {
      int label_true = GenLabel(ctx);
      int label_end = GenLabel(ctx);
      Generate(ctx, node->lhs, 0);
      printf("jnz l%d\n", label_true);
      Generate(ctx, node->rhs, 0);
      printf("jnz l%d\n", label_true);
      printf("push 0\n");
      printf("jmp l%d\n", label_end);
      printf("l%d:\n", label_true);
      printf("push 1\n");
      printf("l%d:\n", label_end);
    }
    break;
  case kNodeString:
    ctx->strings[ctx->num_strings] = node->token;
    printf("push STR_%d\n", ctx->num_strings);
    ctx->num_strings++;
    break;
  case kNodeAnd:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    printf("and\n");
    break;
  case kNodeXor:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    printf("xor\n");
    break;
  case kNodeOr:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    printf("or\n");
    break;
  case kNodeNot:
    Generate(ctx, node->rhs, 0);
    printf("not\n");
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

  struct GenContext gen_ctx = {
    NewSymbol(kSymHead, NULL), 0x20, 0, 0, {}, {-1, -1}
  };
  Generate(&gen_ctx, ast, 0);

  for (int i = 0; i < gen_ctx.num_strings; i++) {
    struct Token *tk_str = gen_ctx.strings[i];
    printf("STR_%d: \ndb ", i);
    for (int i = 1; i < tk_str->len - 1; i++) {
      if (tk_str->raw[i] == '\\') {
        printf("0x%02x,", DecodeEscape(tk_str->raw[i + 1]));
        i++;
      } else {
        printf("0x%02x,", tk_str->raw[i]);
      }
    }
    printf("0\n");
  }

  return 0;
}
