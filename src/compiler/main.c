#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"
#include "symbol.h"
#include "token.h"
#include "type.h"

#define INDENT "\t"

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
  int lvar_offset;
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
  case kNodeInteger:
    if ((node->token->value.as_int >> 15) == 0) {
      printf(INDENT "push %d\n", node->token->value.as_int);
    } else {
      printf(INDENT "push %d\n", node->token->value.as_int >> 8);
      printf(INDENT "push %d\n", node->token->value.as_int & 0xff);
      printf(INDENT "join\n");
    }
    break;
  case kNodeId:
    {
      struct Symbol *sym = FindSymbol(ctx->syms, node->token);
      if (sym) {
        switch (sym->kind) {
        case kSymHead:
          fprintf(stderr, "this must not happen");
          exit(1);
          break;
        case kSymLVar:
          assert(sym->type);
          node->type = sym->type;
          if (sym->type->kind == kTypeArray) {
            if (lval) {
              fprintf(stderr, "array itself cannot be l-value: %.*s\n",
                      sym->name->len, sym->name->raw);
              exit(1);
            }
            printf(INDENT "pushbp\n");
            printf(INDENT "push 0x%x\n", sym->offset);
            printf(INDENT "add\n");
          } else {
            printf(INDENT "pushbp\n");
            printf(INDENT "push 0x%x\n", sym->offset);
            printf(INDENT "add\n");
            if (!lval) {
              if (SizeofType(sym->type) == 1) {
                printf(INDENT "ldd.1\n");
              } else {
                printf(INDENT "ldd\n");
              }
            }
          }
          break;
        case kSymFunc:
          printf(INDENT "push %.*s\n", sym->name->len, sym->name->raw);
          break;
        }
      } else {
        fprintf(stderr, "unknown symbol\n");
        Locate(node->token->raw);
        exit(1);
      }
    }
    break;
  case kNodeAdd:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    if (node->lhs->type &&
        (node->lhs->type->kind == kTypePtr ||
        node->lhs->type->kind == kTypeArray)) {
      size_t element_size = SizeofType(node->lhs->type->base);
      if (element_size > 1) {
        printf(INDENT "push %d\n", (int)element_size);
        printf(INDENT "mul\n");
      }
    }
    printf(INDENT "add\n");
    node->type = node->lhs->type;
    break;
  case kNodeSub:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf(INDENT "sub\n");
    node->type = node->lhs->type;
    break;
  case kNodeMul:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf(INDENT "mul\n");
    node->type = node->lhs->type;
    break;
  case kNodeAssign:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 1);
    printf(INDENT "%s%s\n",
           lval ? "sta" : "std",
           SizeofType(node->lhs->type) == 1 ? ".1" : "");
    node->type = node->lhs->type;
    break;
  case kNodeLT:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf(INDENT "lt\n");
    break;
  case kNodeInc:
  case kNodeDec:
    if (node->lhs) { // 後置インクリメント 'exp ++'
      Generate(ctx, node->lhs, 0);
      printf(INDENT "push 1\n");
      printf(INDENT "dup 1\n");
      printf(node->kind == kNodeInc ? "add\n" : "sub\n");
      Generate(ctx, node->lhs, 1);
      printf(INDENT "sta.%d\n", (int)SizeofType(node->lhs->type));
      printf(INDENT "pop\n");
      node->type = node->lhs->type;
    } else { // 前置インクリメント '++ exp'
      printf(INDENT "push 1\n");
      Generate(ctx, node->rhs, 0);
      printf(node->kind == kNodeInc ? INDENT "add\n" : INDENT "sub\n");
      Generate(ctx, node->rhs, 1);
      printf(INDENT "std.%d\n", (int)SizeofType(node->rhs->type));
      node->type = node->rhs->type;
    }
    break;
  case kNodeEq:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf(INDENT "eq\n");
    break;
  case kNodeNEq:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf(INDENT "neq\n");
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
        printf(INDENT "ldd.1\n");
      } else {
        printf(INDENT "ldd\n");
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
      printf(INDENT "jz L_%d\n", label_false);
      Generate(ctx, node->rhs, 0);
      printf(INDENT "jz L_%d\n", label_false);
      printf(INDENT "push 1\n");
      printf(INDENT "jmp L_%d\n", label_end);
      printf("L_%d:\n", label_false);
      printf(INDENT "push 0\n");
      printf("L_%d:\n", label_end);
    }
    break;
  case kNodeLOr:
    {
      int label_true = GenLabel(ctx);
      int label_end = GenLabel(ctx);
      Generate(ctx, node->lhs, 0);
      printf(INDENT "jnz l%d\n", label_true);
      Generate(ctx, node->rhs, 0);
      printf(INDENT "jnz l%d\n", label_true);
      printf(INDENT "push 0\n");
      printf(INDENT "jmp l%d\n", label_end);
      printf("l%d:\n", label_true);
      printf(INDENT "push 1\n");
      printf("l%d:\n", label_end);
    }
    break;
  case kNodeString:
    ctx->strings[ctx->num_strings] = node->token;
    printf(INDENT "push STR_%d\n", ctx->num_strings);
    ctx->num_strings++;
    break;
  case kNodeAnd:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    printf(INDENT "and\n");
    break;
  case kNodeXor:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    printf(INDENT "xor\n");
    break;
  case kNodeOr:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    printf(INDENT "or\n");
    break;
  case kNodeNot:
    Generate(ctx, node->rhs, 0);
    printf(INDENT "not\n");
    break;
  case kNodeRShift:
  case kNodeLShift:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    printf(INDENT "%s\n", node->kind == kNodeRShift ? "sar" : "shl");
    break;
  case kNodeCall:
    {
      struct Node *args[10];
      int num_args = 0;
      for (struct Node *arg = node->rhs; arg; arg = arg->next) {
        if (num_args >= 10) {
          fprintf(stderr, "the number of arguments must be < 10\n");
          Locate(arg->token->raw);
          exit(1);
        }
        args[num_args++] = arg;
      }
      for (int i = 0; i < num_args; i++) {
        Generate(ctx, args[num_args - 1 - i], 0);
      }
      if (node->lhs->kind == kNodeId) {
        printf(INDENT "call %.*s\n", node->lhs->token->len, node->lhs->token->raw);
      } else {
        fprintf(stderr, "not implemented call of non-id expression\n");
        Locate(node->lhs->token->raw);
        exit(1);
      }
    }
    break;
  case kNodeExprEnd:
    fprintf(stderr, "kNodeExprEnd must not be used\n");
    exit(1);
    break;
  case kNodeDefFunc:
    {
      struct Symbol *func_sym = NewSymbol(kSymFunc, node->token);
      AppendSymbol(ctx->syms, func_sym);
      printf("%.*s:\n", func_sym->name->len, func_sym->name->raw);
      printf(INDENT "enter\n");
      ctx->lvar_offset = 2;
      for (struct Node *param = node->cond; param; param = param->next) {
        struct Symbol *sym = NewSymbol(kSymLVar, param->lhs->token);
        sym->offset = ctx->lvar_offset;
        sym->type = param->type;
        assert(sym->type);
        AppendSymbol(ctx->syms, sym);
        printf(INDENT "pushbp\n");
        printf(INDENT "push 0x%x\n", sym->offset);
        printf(INDENT "add\n");
        printf(INDENT "std\n");
        printf(INDENT "pop\n");
        ctx->lvar_offset += 2;
      }
      printf(INDENT "pushbp\n");
      printf(INDENT "push 0x%x\n", ctx->lvar_offset);
      printf(INDENT "add\n");
      printf(INDENT "popfp\n");
      Generate(ctx, node->rhs, 0);
    }
    break;
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(ctx, n, 0);
      if (n->kind <= kNodeExprEnd) {
        printf(INDENT "pop\n");
      }
    }
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(ctx, node->lhs, 0);
    }
    printf(INDENT "leave\n");
    printf(INDENT "ret\n");
    break;
  case kNodeDefVar:
    {
      struct Symbol *sym = NewSymbol(kSymLVar, node->lhs->token);
      sym->offset = ctx->lvar_offset;

      assert(node->type);
      sym->type = node->type;

      size_t stk_size = (SizeofType(sym->type) + 1) & ~((size_t)1);
      ctx->lvar_offset += stk_size;
      AppendSymbol(ctx->syms, sym);
      printf(INDENT "pushfp\n");
      printf(INDENT "push 0x%x\n", (unsigned int)stk_size);
      printf(INDENT "add\n");
      printf(INDENT "popfp\n");

      if (node->rhs) {
        Generate(ctx, node->rhs, 0);
        printf(INDENT "pushbp\n");
        printf(INDENT "push 0x%x\n", sym->offset);
        printf(INDENT "add\n");
        if (SizeofType(sym->type) == 1) {
          printf(INDENT "sta.1\n");
        } else {
          printf(INDENT "sta\n");
        }
        printf(INDENT "pop\n");
      }
    }
    break;
  case kNodeIf:
    {
      int label_else = node->rhs ? GenLabel(ctx) : -1;
      int label_end = GenLabel(ctx);
      Generate(ctx, node->cond, 0);
      printf(INDENT "jz L_%d\n", node->rhs ? label_else : label_end);
      Generate(ctx, node->lhs, 0);
      if (node->rhs) {
        printf(INDENT "jmp L_%d\n", label_end);
        printf("L_%d:\n", label_else);
        Generate(ctx, node->rhs, 0);
      }
      printf("L_%d:\n", label_end);
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
      printf(INDENT "pop\n");
      printf("L_%d:\n", label_cond);
      Generate(ctx, node->cond, 0);
      printf(INDENT "jz L_%d\n", label_end);
      Generate(ctx, node->rhs, 0);
      if (node->rhs->kind <= kNodeExprEnd) {
        printf(INDENT "pop\n");
      }
      printf("L_%d:\n", label_next);
      Generate(ctx, node->lhs->next, 0);
      printf(INDENT "pop\n");
      printf(INDENT "jmp L_%d\n", label_cond);
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
      printf(INDENT "jz L_%d\n", label_end);
      Generate(ctx, node->rhs, 0);
      printf(INDENT "jmp L_%d\n", label_cond);
      printf("L_%d:\n", label_end);

      ctx->jump_labels = old_labels;
    }
    break;
  case kNodeBreak:
    printf(INDENT "jmp L_%d\n", ctx->jump_labels.lbreak);
    break;
  case kNodeContinue:
    printf(INDENT "jmp L_%d\n", ctx->jump_labels.lcontinue);
    break;
  case kNodeTypeSpec:
  case kNodePList:
    break;
  }
}

int main(void) {
  src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, stdin);
  src[src_len] = '\0';

  Tokenize(src);
  struct Node *ast = Program();
  Expect(kTokenEOF);

  struct GenContext gen_ctx = {
    NewSymbol(kSymHead, NULL), 2, 0, 0, {}, {-1, -1}
  };
  printf(INDENT "push 0x20\n");
  printf(INDENT "popfp\n");
  printf(INDENT "call main\n");
  printf(INDENT "st 0x1e\n");
  printf("fin:\n");
  printf(INDENT "jmp fin\n");
  for (struct Node *n = ast; n; n = n->next) {
    if (n->kind == kNodeDefFunc) {
      Generate(&gen_ctx, n, 0);
    }
  }

  for (int i = 0; i < gen_ctx.num_strings; i++) {
    struct Token *tk_str = gen_ctx.strings[i];
    printf("STR_%d: \n" INDENT "db ", i);
    for (int i = 1; i < tk_str->len - 1; i++) {
      if (tk_str->raw[i] == '\\') {
        printf("0x%02x,", DecodeEscape(tk_str->raw[i + 1]));
        i++;
      } else {
        printf("0x%02x,", tk_str->raw[i]);
      }
    }
    printf(INDENT "0\n");
  }

  return 0;
}
