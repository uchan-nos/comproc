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
#define MAX_LINE 4096

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
  int line_add_fp; // add fp, N 命令が最後に配置された行番号
  int num_label;
  int num_strings;
  struct Token *strings[4];
  struct JumpLabels jump_labels;
  int num_line;
  struct AsmLine asm_lines[MAX_LINE];
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
  struct AsmLine *line = &ctx->asm_lines[ctx->num_line++];
  line->kind = kAsmLineInsn;
  struct Instruction *i = &line->insn;
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

struct Label *AddLabel(struct GenContext *ctx) {
  struct AsmLine *line = &ctx->asm_lines[ctx->num_line++];
  line->kind = kAsmLineLabel;
  return &line->label;
}

struct Label *AddLabelToken(struct GenContext *ctx, struct Token *t) {
  struct Label *l = AddLabel(ctx);
  l->kind = kLabelToken;
  l->token = t;
  return l;
}

struct Label *AddLabelAutoL(struct GenContext *ctx, int no) {
  struct Label *l = AddLabel(ctx);
  l->kind = kLabelAutoL;
  l->label_no = no;
  return l;
}

struct Label *AddLabelStr(struct GenContext *ctx, const char *s) {
  struct Label *l = AddLabel(ctx);
  l->kind = kLabelStr;
  l->label_str = s;
  return l;
}

void Generate(struct GenContext *ctx, struct Node *node, int lval) {
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
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
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
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "sub");
    node->type = node->lhs->type;
    break;
  case kNodeMul:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "mul");
    node->type = node->lhs->type;
    break;
  case kNodeAssign:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 1);
    if (SizeofType(node->lhs->type) == 1) {
      Insn(ctx, lval ? "sta.1" : "std.1");
    } else {
      Insn(ctx, lval ? "sta" : "std");
    }
    node->type = node->lhs->type;
    break;
  case kNodeLT:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "lt");
    break;
  case kNodeInc:
  case kNodeDec:
    if (node->lhs) { // 後置インクリメント 'exp ++'
      Generate(ctx, node->lhs, 0);
      InsnInt(ctx, "push", 1);
      InsnInt(ctx, "dup", 1);
      Insn(ctx, node->kind == kNodeInc ? "add" : "sub");
      Generate(ctx, node->lhs, 1);
      Insn(ctx, SizeofType(node->lhs->type) == 1 ? "sta.1" : "sta");
      Insn(ctx, "pop");
      node->type = node->lhs->type;
    } else { // 前置インクリメント '++ exp'
      InsnInt(ctx, "push", 1);
      Generate(ctx, node->rhs, 0);
      Insn(ctx, node->kind == kNodeInc ? "add" : "sub");
      Generate(ctx, node->rhs, 1);
      Insn(ctx, SizeofType(node->rhs->type) == 1 ? "std.1" : "std");
      node->type = node->rhs->type;
    }
    break;
  case kNodeEq:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "eq");
    break;
  case kNodeNEq:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "neq");
    break;
  case kNodeRef:
    Generate(ctx, node->rhs, 1);
    break;
  case kNodeDeref:
    if (lval) {
      Generate(ctx, node->rhs, 0);
    } else {
      Generate(ctx, node->rhs, 0);
      Insn(ctx, SizeofType(node->rhs->type->base) == 1 ? "ldd.1" : "ldd");
    }
    assert(node->rhs->type->base);
    node->type = node->rhs->type->base;
    break;
  case kNodeLAnd:
    {
      int label_false = GenLabel(ctx);
      int label_end = GenLabel(ctx);
      Generate(ctx, node->lhs, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_false);
      Generate(ctx, node->rhs, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_false);
      InsnInt(ctx, "push", 1);
      InsnLabelAutoL(ctx, "jmp", label_end);
      AddLabelAutoL(ctx, label_false);
      InsnInt(ctx, "push", 0);
      AddLabelAutoL(ctx, label_end);
    }
    break;
  case kNodeLOr:
    {
      int label_true = GenLabel(ctx);
      int label_end = GenLabel(ctx);
      Generate(ctx, node->lhs, 0);
      InsnLabelAutoL(ctx, "jnz", label_true);
      Generate(ctx, node->rhs, 0);
      InsnLabelAutoL(ctx, "jnz", label_true);
      InsnInt(ctx, "push", 0);
      InsnLabelAutoL(ctx, "jmp", label_end);
      AddLabelAutoL(ctx, label_true);
      InsnInt(ctx, "push", 1);
      AddLabelAutoL(ctx, label_end);
    }
    break;
  case kNodeString:
    ctx->strings[ctx->num_strings] = node->token;
    InsnLabelAutoS(ctx, "push", ctx->num_strings);
    ctx->num_strings++;
    break;
  case kNodeAnd:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "and");
    break;
  case kNodeXor:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "xor");
    break;
  case kNodeOr:
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "or");
    break;
  case kNodeNot:
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "not");
    break;
  case kNodeRShift:
  case kNodeLShift:
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, node->kind == kNodeRShift ? "sar" : "shl");
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
        InsnLabelToken(ctx, "call", node->lhs->token);
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
      AddLabelToken(ctx, func_sym->name);
      InsnReg(ctx, "cpush", "fp");
      ctx->lvar_offset = 0;
      for (struct Node *param = node->cond; param; param = param->next) {
        struct Symbol *sym = NewSymbol(kSymLVar, param->lhs->token);
        sym->offset = ctx->lvar_offset;
        sym->type = param->type;
        assert(sym->type);
        AppendSymbol(ctx->syms, sym);
        InsnBaseOff(ctx, "st", "cstack", sym->offset);
        ctx->lvar_offset += 2;
      }
      ctx->line_add_fp = ctx->num_line;
      // add fp のオペランド値は、関数定義の処理後に上書きされる
      InsnRegInt(ctx, "add", "fp", 0 /* ダミーの値 */);
      Generate(ctx, node->rhs, 0);

      struct Node *block_last = GetLastNode(node->rhs);
      if (block_last && block_last->kind != kNodeReturn) {
        InsnReg(ctx, "cpop", "fp");
        Insn(ctx, "ret");
      }
    }
    break;
  case kNodeBlock:
    for (struct Node *n = node->next; n; n = n->next) {
      Generate(ctx, n, 0);
      if (n->kind <= kNodeExprEnd) {
        Insn(ctx, "pop");
      }
    }
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(ctx, node->lhs, 0);
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

      if (node->rhs) {
        Generate(ctx, node->rhs, 0);
        InsnBaseOff(ctx, "push", "cstack", sym->offset);
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
      int label_end = GenLabel(ctx);
      Generate(ctx, node->cond, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", node->rhs ? label_else : label_end);
      Generate(ctx, node->lhs, 0);
      if (node->rhs) {
        InsnLabelAutoL(ctx, "jmp", label_end);
        AddLabelAutoL(ctx, label_else);
        Generate(ctx, node->rhs, 0);
      }
      AddLabelAutoL(ctx, label_end);
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
      Insn(ctx, "pop");
      AddLabelAutoL(ctx, label_cond);
      Generate(ctx, node->cond, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_end);
      Generate(ctx, node->rhs, 0);
      if (node->rhs->kind <= kNodeExprEnd) {
        Insn(ctx, "pop");
      }
      AddLabelAutoL(ctx, label_next);
      Generate(ctx, node->lhs->next, 0);
      Insn(ctx, "pop");
      InsnLabelAutoL(ctx, "jmp", label_cond);
      AddLabelAutoL(ctx, label_end);

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

      AddLabelAutoL(ctx, label_cond);
      Generate(ctx, node->cond, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_end);
      Generate(ctx, node->rhs, 0);
      InsnLabelAutoL(ctx, "jmp", label_cond);
      AddLabelAutoL(ctx, label_end);

      ctx->jump_labels = old_labels;
    }
    break;
  case kNodeBreak:
    InsnLabelAutoL(ctx, "jmp", ctx->jump_labels.lbreak);
    break;
  case kNodeContinue:
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
    NewSymbol(kSymHead, NULL), 2, 0, 0, 0, {}, {-1, -1}, 0, {}
  };
  InsnRegInt(&gen_ctx, "add", "fp", 0x100);
  InsnLabelStr(&gen_ctx, "call", "main");
  InsnBaseOff(&gen_ctx, "st", NULL, 0x82);
  AddLabelStr(&gen_ctx, "fin");
  InsnLabelStr(&gen_ctx, "jmp", "fin");
  for (struct Node *n = ast; n; n = n->next) {
    if (n->kind == kNodeDefFunc) {
      Generate(&gen_ctx, n, 0);
      struct AsmLine *line = &gen_ctx.asm_lines[gen_ctx.line_add_fp];
      if (line->kind != kAsmLineInsn ||
          strcmp(line->insn.opcode, "add") != 0 ||
          line->insn.operands[0].kind != kOprReg ||
          line->insn.operands[1].kind != kOprInt) {
        fprintf(stderr, "line %d must be 'add fp, N'\n", gen_ctx.line_add_fp);
        exit(1);
      }
      if (gen_ctx.lvar_offset == 0) {
        line->kind = kAsmLineDeleted;
      } else {
        line->insn.operands[1].val_int = gen_ctx.lvar_offset;
      }
    }
  }

  OptimizeAsmLines(gen_ctx.asm_lines, gen_ctx.num_line);

  for (int i = 0; i < gen_ctx.num_line; i++) {
    struct AsmLine *line = gen_ctx.asm_lines + i;
    switch (line->kind) {
    case kAsmLineDeleted:
      break; // 何もしない
    case kAsmLineLabel:
      PrintLabel(stdout, &line->label);
      printf(":\n");
      break;
    case kAsmLineInsn:
      printf(INDENT "%s", line->insn.opcode);
      for (int opr_i = 0;
           opr_i < MAX_OPERANDS && line->insn.operands[opr_i].kind != kOprNone;
           opr_i++) {
        struct Operand *opr = line->insn.operands + opr_i;
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
      break;
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
