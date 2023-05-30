#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ast.h"
#include "insn.h"
#include "symbol.h"
#include "token.h"
#include "type.h"

#define INDENT "\t"
#define MAX_INSN 4096

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
  int num_insn;
  struct Instruction insn[MAX_INSN];
};

int GenLabel(struct GenContext *ctx) {
  return ++ctx->num_label; // L_n ラベルは 1 始まり
}

// node->next を辿り、末尾の要素（node->next == NULL となる node）を返す
struct Node *GetLastNode(struct Node *node) {
  for (; node->next; node = node->next) {
  }
  return node;
}

struct Instruction *Insn(struct GenContext *ctx, const char *opcode) {
  struct Instruction *i = &ctx->insn[ctx->num_insn++];
  SetInsnNoOpr(i, opcode);
  return i;
}

struct Instruction *InsnInt(struct GenContext *ctx, const char *opcode, int opr1) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprInt;
  i->operands[0].val_int = opr1;
  return i;
}

struct Instruction *InsnReg(struct GenContext *ctx, const char *opcode, const char *opr1) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprReg;
  i->operands[0].val_reg = opr1;
  return i;
}

struct Instruction *InsnRegInt(struct GenContext *ctx, const char *opcode, const char *opr1, int opr2) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprReg;
  i->operands[0].val_reg = opr1;
  i->operands[1].kind = kOprInt;
  i->operands[1].val_int = opr2;
  return i;
}

struct Instruction *InsnBaseOff(struct GenContext *ctx, const char *opcode, const char *base, int off) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprBaseOff;
  i->operands[0].val_base_off.base = base;
  i->operands[0].val_base_off.offset = off;
  return i;
}

struct Instruction *InsnLabelStr(struct GenContext *ctx, const char *opcode, const char *label) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprLabel;
  i->operands[0].val_label.kind = kLabelStr;
  i->operands[0].val_label.label_str = label;
  return i;
}

struct Instruction *InsnLabel(struct GenContext *ctx, const char *opcode, struct Label *label) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprLabel;
  i->operands[0].val_label = *label;
  return i;
}

struct Instruction *InsnLabelToken(struct GenContext *ctx, const char *opcode, struct Token *label) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprLabel;
  i->operands[0].val_label.kind = kLabelToken;
  i->operands[0].val_label.token = label;
  return i;
}

struct Instruction *InsnLabelAuto(struct GenContext *ctx, const char *opcode, enum LabelKind kind, int label) {
  struct Instruction *i = Insn(ctx, opcode);
  i->operands[0].kind = kOprLabel;
  i->operands[0].val_label.kind = kind;
  i->operands[0].val_label.label_no = label;
  return i;
}

struct Instruction *InsnLabelAutoL(struct GenContext *ctx, const char *opcode, int label) {
  return InsnLabelAuto(ctx, opcode, kLabelAutoL, label);
}

struct Instruction *InsnLabelAutoS(struct GenContext *ctx, const char *opcode, int label) {
  return InsnLabelAuto(ctx, opcode, kLabelAutoS, label);
}

struct Label *AllocLabelToken(struct Token *t) {
  struct Label *l = malloc(sizeof(struct Label));
  l->kind = kLabelToken;
  l->token = t;
  return l;
}

struct Label *AllocLabelStr(const char *s) {
  struct Label *l = malloc(sizeof(struct Label));
  l->kind = kLabelStr;
  l->label_str = s;
  return l;
}

struct Label *AllocLabelAutoL(int no) {
  struct Label *l = malloc(sizeof(struct Label));
  l->kind = kLabelAutoL;
  l->label_no = no;
  return l;
}

// label_exit: 出口ラベル。このノードを脱出するためのジャンプ先ラベル。0 で自動生成。
void Generate(struct GenContext *ctx, struct Node *node, int lval, int label_exit) {
  switch (node->kind) {
  case kNodeInteger:
    if ((node->token->value.as_int >> 15) == 0) {
      InsnInt(ctx, "push", node->token->value.as_int);
    } else {
      InsnInt(ctx, "push", node->token->value.as_int >> 8);
      InsnInt(ctx, "push", node->token->value.as_int & 0xff);
      Insn(ctx, "join");
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
            InsnBaseOff(ctx, "push", "cstack", sym->offset);
          } else {
            InsnBaseOff(ctx, "push", "cstack", sym->offset);
            if (!lval) {
              if (SizeofType(sym->type) == 1) {
                Insn(ctx, "ldd.1");
              } else {
                Insn(ctx, "ldd");
              }
            }
          }
          break;
        case kSymFunc:
          //printf(INDENT "push %.*s\n", sym->name->len, sym->name->raw);
          InsnLabelToken(ctx, "push", sym->name);
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
    Generate(ctx, node->lhs, 0, 0);
    Generate(ctx, node->rhs, 0, 0);
    if (node->lhs->type &&
        (node->lhs->type->kind == kTypePtr ||
        node->lhs->type->kind == kTypeArray)) {
      size_t element_size = SizeofType(node->lhs->type->base);
      if (element_size > 1) {
        InsnInt(ctx, "push", (int)element_size);
        Insn(ctx, "mul");
      }
    }
    Insn(ctx, "add");
    node->type = node->lhs->type;
    break;
  case kNodeSub:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 0, 0);
    Insn(ctx, "sub");
    node->type = node->lhs->type;
    break;
  case kNodeMul:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 0, 0);
    Insn(ctx, "mul");
    node->type = node->lhs->type;
    break;
  case kNodeAssign:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 1, 0);
    if (SizeofType(node->lhs->type) == 1) {
      Insn(ctx, lval ? "sta.1" : "std.1");
    } else {
      Insn(ctx, lval ? "sta" : "std");
    }
    node->type = node->lhs->type;
    break;
  case kNodeLT:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 0, 0);
    Insn(ctx, "lt");
    break;
  case kNodeInc:
  case kNodeDec:
    if (node->lhs) { // 後置インクリメント 'exp ++'
      Generate(ctx, node->lhs, 0, 0);
      InsnInt(ctx, "push", 1);
      InsnInt(ctx, "dup", 1);
      //printf(node->kind == kNodeInc ? "add\n" : "sub\n");
      Insn(ctx, node->kind == kNodeInc ? "add" : "sub");
      Generate(ctx, node->lhs, 1, 0);
      //printf(INDENT "sta.%d\n", (int)SizeofType(node->lhs->type));
      Insn(ctx, SizeofType(node->lhs->type) == 1 ? "sta.1" : "sta");
      //printf(INDENT "pop\n");
      Insn(ctx, "pop");
      node->type = node->lhs->type;
    } else { // 前置インクリメント '++ exp'
      //printf(INDENT "push 1\n");
      InsnInt(ctx, "push", 1);
      Generate(ctx, node->rhs, 0, 0);
      //printf(node->kind == kNodeInc ? INDENT "add\n" : INDENT "sub\n");
      Insn(ctx, node->kind == kNodeInc ? "add" : "sub");
      Generate(ctx, node->rhs, 1, 0);
      //printf(INDENT "std.%d\n", (int)SizeofType(node->rhs->type));
      Insn(ctx, SizeofType(node->rhs->type) == 1 ? "std.1" : "std");
      node->type = node->rhs->type;
    }
    break;
  case kNodeEq:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 0, 0);
    // printf(INDENT "eq\n");
    Insn(ctx, "eq");
    break;
  case kNodeNEq:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 0, 0);
    Insn(ctx, "neq");
    // printf(INDENT "neq\n");
    break;
  case kNodeRef:
    Generate(ctx, node->rhs, 1, 0);
    break;
  case kNodeDeref:
    if (lval) {
      Generate(ctx, node->rhs, 0, 0);
    } else {
      Generate(ctx, node->rhs, 0, 0);
      Insn(ctx, SizeofType(node->rhs->type->base) == 1 ? "ldd.1" : "ldd");
    }
    assert(node->rhs->type->base);
    node->type = node->rhs->type->base;
    break;
  case kNodeLAnd:
    {
      int label_false = GenLabel(ctx);
      Generate(ctx, node->lhs, 0, 0);
      // printf(INDENT "push 0\n");
      // printf(INDENT "neq\n");
      // printf(INDENT "jz L_%d\n", label_false);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_false);
      Generate(ctx, node->rhs, 0, 0);
      // printf(INDENT "push 0\n");
      // printf(INDENT "neq\n");
      // printf(INDENT "jz L_%d\n", label_false);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_false);
      // printf(INDENT "push 1\n");
      // printf(INDENT "jmp L_%d\n", label_end);
      InsnInt(ctx, "push", 1);
      InsnLabelAutoL(ctx, "jmp", label_exit);
      // printf("L_%d:\n", label_false);
      // printf(INDENT "push 0\n");
      // printf("L_%d:\n", label_end);
      InsnInt(ctx, "push", 0)->label = AllocLabelAutoL(label_false);
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_exit);
    }
    break;
  case kNodeLOr:
    {
      int label_true = GenLabel(ctx);
      Generate(ctx, node->lhs, 0, 0);
      // printf(INDENT "jnz l%d\n", label_true);
      InsnLabelAutoL(ctx, "jnz", label_true);
      Generate(ctx, node->rhs, 0, 0);
      // printf(INDENT "jnz l%d\n", label_true);
      // printf(INDENT "push 0\n");
      // printf(INDENT "jmp l%d\n", label_end);
      InsnLabelAutoL(ctx, "jnz", label_true);
      InsnInt(ctx, "push", 0);
      InsnLabelAutoL(ctx, "jmp", label_exit);
      // printf("l%d:\n", label_true);
      // printf(INDENT "push 1\n");
      // printf("l%d:\n", label_end);
      InsnInt(ctx, "push", 1)->label = AllocLabelAutoL(label_true);
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_exit);
    }
    break;
  case kNodeString:
    ctx->strings[ctx->num_strings] = node->token;
    // printf(INDENT "push STR_%d\n", ctx->num_strings);
    InsnLabelAutoS(ctx, "push", ctx->num_strings);
    ctx->num_strings++;
    break;
  case kNodeAnd:
    Generate(ctx, node->lhs, 0, 0);
    Generate(ctx, node->rhs, 0, 0);
    printf(INDENT "and\n");
    break;
  case kNodeXor:
    Generate(ctx, node->lhs, 0, 0);
    Generate(ctx, node->rhs, 0, 0);
    printf(INDENT "xor\n");
    break;
  case kNodeOr:
    Generate(ctx, node->lhs, 0, 0);
    Generate(ctx, node->rhs, 0, 0);
    printf(INDENT "or\n");
    break;
  case kNodeNot:
    Generate(ctx, node->rhs, 0, 0);
    printf(INDENT "not\n");
    break;
  case kNodeRShift:
  case kNodeLShift:
    Generate(ctx, node->rhs, 0, 0);
    Generate(ctx, node->lhs, 0, 0);
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
        Generate(ctx, args[num_args - 1 - i], 0, 0);
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
      InsnReg(ctx, "cpush", "fp")->label = AllocLabelToken(func_sym->name);
      //printf("%.*s:\n", func_sym->name->len, func_sym->name->raw);
      //printf(INDENT "cpush fp\n");
      ctx->lvar_offset = 0;
      for (struct Node *param = node->cond; param; param = param->next) {
        struct Symbol *sym = NewSymbol(kSymLVar, param->lhs->token);
        sym->offset = ctx->lvar_offset;
        sym->type = param->type;
        assert(sym->type);
        AppendSymbol(ctx->syms, sym);
        InsnBaseOff(ctx, "st", "cstack", sym->offset);
        //printf(INDENT "st cstack+0x%x\n", sym->offset);
        ctx->lvar_offset += 2;
      }
      InsnRegInt(ctx, "add", "fp", ctx->lvar_offset);
      //printf(INDENT "add fp,0x%x\n", ctx->lvar_offset);
      Generate(ctx, node->rhs, 0, 0);

      struct Node *block_last = GetLastNode(node->rhs);
      if (block_last && block_last->kind != kNodeReturn) {
        InsnReg(ctx, "cpop", "fp");
        Insn(ctx, "ret");
        //printf(INDENT "cpop fp\n");
        //printf(INDENT "ret\n");
      }
    }
    break;
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(ctx, n, 0, 0);
      if (n->kind <= kNodeExprEnd) {
        printf(INDENT "pop\n");
      }
    }
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(ctx, node->lhs, 0, 0);
    }
    InsnReg(ctx, "cpop", "fp");
    Insn(ctx, "ret");
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
      InsnRegInt(ctx, "add", "fp", stk_size);
      //printf(INDENT "add fp,0x%x\n", (unsigned int)stk_size);

      if (node->rhs) {
        Generate(ctx, node->rhs, 0, 0);
        InsnBaseOff(ctx, "push", "cstack", sym->offset);
        //printf(INDENT "push cstack+0x%x\n", sym->offset);
        if (SizeofType(sym->type) == 1) {
          Insn(ctx, "sta.1");
        } else {
          Insn(ctx, "sta");
        }
        Insn(ctx, "pop");
      }
    }
    break;
  case kNodeIf:
    {
      int label_else = node->rhs ? GenLabel(ctx) : -1;
      if (label_exit == 0) {
        label_exit = GenLabel(ctx);
      }
      Generate(ctx, node->cond, 0, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", node->rhs ? label_else : label_exit);
      Generate(ctx, node->lhs, 0, 0);
      if (node->rhs) {
        InsnLabelAutoL(ctx, "jmp", label_exit);
        ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_else);
        Generate(ctx, node->rhs, 0, 0);
      }
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_exit);
    }
    break;
  case kNodeFor:
    {
      int label_cond = GenLabel(ctx);
      if (label_exit == 0) {
        label_exit = GenLabel(ctx);
        fprintf(stderr, "kNodeFor: label_exit is 0. generating new label = %d\n", label_exit);
      }
      int label_next = GenLabel(ctx);
      fprintf(stderr, "kNodeFor: label_cond=%d label_exit=%d label_next=%d\n",
              label_cond, label_exit, label_next);

      struct JumpLabels old_labels = ctx->jump_labels;
      ctx->jump_labels.lbreak = label_exit;
      ctx->jump_labels.lcontinue = label_next;

      fprintf(stderr, "Generating init node\n");
      Generate(ctx, node->lhs, 0, 0);
      Insn(ctx, "pop");
      //printf(INDENT "pop\n");
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_cond);
      fprintf(stderr, "Generating cond node\n");
      Generate(ctx, node->cond, 0, 0);
      // printf(INDENT "push 0\n");
      // printf(INDENT "neq\n");
      // printf(INDENT "jz L_%d\n", label_end);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_exit);
      fprintf(stderr, "Generating body node\n");
      Generate(ctx, node->rhs, 0, label_next);
      if (node->rhs->kind <= kNodeExprEnd) {
        Insn(ctx, "pop");
        // printf(INDENT "pop\n");
      }
      // printf("L_%d:\n", label_next);
      //ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_next);
      fprintf(stderr, "Generating next node\n");
      Generate(ctx, node->lhs->next, 0, 0);
      Insn(ctx, "pop");
      // printf(INDENT "pop\n");
      // printf(INDENT "jmp L_%d\n", label_cond);
      // printf("L_%d:\n", label_end);
      InsnLabelAutoL(ctx, "jmp", label_cond);
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_exit);

      ctx->jump_labels = old_labels;
    }
    break;
  case kNodeWhile:
    {
      int label_cond = GenLabel(ctx);
      if (label_exit == 0) {
        label_exit = GenLabel(ctx);
      }

      struct JumpLabels old_labels = ctx->jump_labels;
      ctx->jump_labels.lbreak = label_exit;
      ctx->jump_labels.lcontinue = label_cond;

      // printf("L_%d:\n", label_cond);
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_cond);
      Generate(ctx, node->cond, 0, 0);
      // printf(INDENT "push 0\n");
      // printf(INDENT "neq\n");
      // printf(INDENT "jz L_%d\n", label_end);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_exit);
      Generate(ctx, node->rhs, 0, 0);
      // printf(INDENT "jmp L_%d\n", label_cond);
      // printf("L_%d:\n", label_end);
      InsnLabelAutoL(ctx, "jmp", label_cond);
      ctx->insn[ctx->num_insn].label = AllocLabelAutoL(label_exit);

      ctx->jump_labels = old_labels;
    }
    break;
  case kNodeBreak:
    // printf(INDENT "jmp L_%d\n", ctx->jump_labels.lbreak);
    InsnLabelAutoL(ctx, "jmp", ctx->jump_labels.lbreak);
    break;
  case kNodeContinue:
    // printf(INDENT "jmp L_%d\n", ctx->jump_labels.lcontinue);
    InsnLabelAutoL(ctx, "jmp", ctx->jump_labels.lcontinue);
    break;
  case kNodeTypeSpec:
  case kNodePList:
    break;
  }
}

int main(int argc, char **argv) {
  src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, stdin);
  src[src_len] = '\0';

  Tokenize(src);
  struct Node *ast = Program();
  Expect(kTokenEOF);

  if (argc == 2 && strcmp(argv[1], "--ast") == 0) {
    while (ast) {
      PrintNode(ast, 0, NULL);
      ast = ast->next;
    }
    return 0;
  }

  struct GenContext gen_ctx = {
    NewSymbol(kSymHead, NULL), 2, 0, 0, {}, {-1, -1}, 0, {}
  };
  //printf(INDENT "add fp,0x100\n");
  //printf(INDENT "call main\n");
  //printf(INDENT "st 0x82\n");
  InsnRegInt(&gen_ctx, "add", "fp", 0x100);
  InsnLabelStr(&gen_ctx, "call", "main");
  InsnBaseOff(&gen_ctx, "st", NULL, 0x82);
  //printf("fin:\n");
  //printf(INDENT "jmp fin\n");
  InsnLabelStr(&gen_ctx, "jmp", "fin")->label = AllocLabelStr("fin");
  for (struct Node *n = ast; n; n = n->next) {
    if (n->kind == kNodeDefFunc) {
      Generate(&gen_ctx, n, 0, 0);
    }
  }

  for (int i = 0; i < gen_ctx.num_insn; i++) {
    struct Instruction *insn = gen_ctx.insn + i;
    if (insn->label) {
      PrintLabel(stdout, insn->label);
      printf(":\n");
    }
    printf(INDENT "%s", insn->opcode);
    for (int opr_i = 0;
         opr_i < MAX_OPERANDS && insn->operands[opr_i].kind != kOprNone;
         opr_i++) {
      struct Operand *opr = insn->operands + opr_i;
      putchar(" ,"[opr_i > 0]);
      switch (opr->kind) {
      case kOprNone:
        // pass
      case kOprInt:
        printf("%d", opr->val_int);
        break;
      case kOprLabel:
        PrintLabel(stdout, &opr->val_label);
        break;
      case kOprReg:
        printf("%s", opr->val_reg);
        break;
      case kOprBaseOff:
        if (opr->val_base_off.base) {
          printf("%s+", opr->val_base_off.base);
        }
        printf("%d", opr->val_base_off.offset);
        break;
      }
    }
    printf("\n");
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
