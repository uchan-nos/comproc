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
  struct Scope *scope;
  int lvar_offset;
  int line_add_fp; // add fp, N 命令が最後に配置された行番号
  int num_label;
  int num_strings;
  struct Token *strings[4];
  struct JumpLabels jump_labels;
  int num_line;
  struct AsmLine asm_lines[MAX_LINE];
  int print_ast;
  int is_isr; // 現在コンパイルしている関数は ISR である
};

int GenLabel(struct GenContext *ctx) {
  return ++ctx->num_label; // L_n ラベルは 1 始まり
}

struct AsmLine *GenAsmLine(struct GenContext *ctx, enum AsmLineKind kind) {
  if (ctx->num_line >= MAX_LINE) {
    fprintf(stderr, "too many asm lines\n");
    exit(1);
  }
  struct AsmLine *l = &ctx->asm_lines[ctx->num_line++];
  l->kind = kind;
  return l;
}

// node->next を辿り、末尾の要素（node->next == NULL となる node）を返す
struct Node *GetLastNode(struct Node *node) {
  for (; node->next; node = node->next) {
  }
  return node;
}

struct Instruction *Insn(struct GenContext *ctx, const char *opcode) {
  struct AsmLine *line = GenAsmLine(ctx, kAsmLineInsn);
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
  struct AsmLine *line = GenAsmLine(ctx, kAsmLineLabel);
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

#define PRINT_NODE_COMMENT(ctx, n, s) \
  do { \
    if ((ctx)->print_ast) { \
      struct AsmLine *l = GenAsmLine((ctx), kAsmLineIndentedComment); \
      snprintf(l->comment, sizeof(l->comment), \
              "Node[%d]: %s", (n->index), (s)); \
    } \
  } while (0)

void Generate(struct GenContext *ctx, struct Node *node, int lval) {
  switch (node->kind) {
  case kNodeInteger:
    if (node->token->value.as_int <= 0x7ffe) {
      InsnInt(ctx, "push", node->token->value.as_int);
    } else {
      InsnInt(ctx, "push", node->token->value.as_int >> 8);
      InsnInt(ctx, "push", node->token->value.as_int & 0xff);
      Insn(ctx, "join");
    }
    break;
  case kNodeId:
    {
      struct Symbol *sym = FindSymbol(ctx->scope, node->token);
      if (!sym) {
        fprintf(stderr, "unknown symbol\n");
        Locate(node->token->raw);
        exit(1);
      }
      switch (sym->kind) {
      case kSymHead:
        fprintf(stderr, "this must not happen");
        exit(1);
        break;
      case kSymGVar:
        assert(sym->type);
        node->type = sym->type;
        if (sym->type->kind == kTypeArray) {
          if (lval) {
            fprintf(stderr, "array itself cannot be l-value: %.*s\n",
                    sym->name->len, sym->name->raw);
            exit(1);
          }
          InsnInt(ctx, "push", sym->offset);
        } else {
          if (lval) {
            InsnInt(ctx, "push", sym->offset);
          } else {
            if (SizeofType(sym->type) == 1) {
              InsnBaseOff(ctx, "ld.1", "zero", sym->offset);
            } else {
              InsnBaseOff(ctx, "ld", "zero", sym->offset);
            }
          }
        }
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
          if (lval) {
            InsnBaseOff(ctx, "push", "cstack", sym->offset);
          } else {
            if (SizeofType(sym->type) == 1) {
              InsnBaseOff(ctx, "ld.1", "cstack", sym->offset);
            } else {
              InsnBaseOff(ctx, "ld", "cstack", sym->offset);
            }
          }
        }
        break;
      case kSymFunc:
        InsnLabelToken(ctx, "push", sym->name);
        break;
      }
    }
    break;
  case kNodeAdd:
    PRINT_NODE_COMMENT(ctx, node, "Add");
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
    PRINT_NODE_COMMENT(ctx, node, "Sub");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "sub");
    node->type = node->lhs->type;
    break;
  case kNodeMul:
    PRINT_NODE_COMMENT(ctx, node, "Mul");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "mul");
    node->type = node->lhs->type;
    break;
  case kNodeAssign:
    PRINT_NODE_COMMENT(ctx, node, "Assign");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 1);
    assert(node->lhs->type);
    if (SizeofType(node->lhs->type) == 1) {
      Insn(ctx, lval ? "sta.1" : "std.1");
    } else {
      Insn(ctx, lval ? "sta" : "std");
    }
    node->type = node->lhs->type;
    break;
  case kNodeLT:
    PRINT_NODE_COMMENT(ctx, node, "LT");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "lt");
    break;
  case kNodeLE:
    PRINT_NODE_COMMENT(ctx, node, "LE");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "le");
    break;
  case kNodeInc:
  case kNodeDec:
    if (node->lhs) { // 後置インクリメント 'exp ++'
      PRINT_NODE_COMMENT(ctx, node, "Inc/Dec (postfix))");
      Generate(ctx, node->lhs, 0);
      InsnInt(ctx, "push", 1);
      InsnInt(ctx, "dup", 1);
      Insn(ctx, node->kind == kNodeInc ? "add" : "sub");
      Generate(ctx, node->lhs, 1);
      Insn(ctx, SizeofType(node->lhs->type) == 1 ? "sta.1" : "sta");
      Insn(ctx, "pop");
      node->type = node->lhs->type;
    } else { // 前置インクリメント '++ exp'
      PRINT_NODE_COMMENT(ctx, node, "Inc/Dec (prefix))");
      InsnInt(ctx, "push", 1);
      Generate(ctx, node->rhs, 0);
      Insn(ctx, node->kind == kNodeInc ? "add" : "sub");
      Generate(ctx, node->rhs, 1);
      Insn(ctx, SizeofType(node->rhs->type) == 1 ? "std.1" : "std");
      node->type = node->rhs->type;
    }
    break;
  case kNodeEq:
    PRINT_NODE_COMMENT(ctx, node, "Eq");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, "eq");
    break;
  case kNodeNEq:
    PRINT_NODE_COMMENT(ctx, node, "NEq");
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
      PRINT_NODE_COMMENT(ctx, node, "LAnd (eval lhs)");
      Generate(ctx, node->lhs, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_false);
      PRINT_NODE_COMMENT(ctx, node, "LAnd (eval rhs)");
      Generate(ctx, node->rhs, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_false);
      PRINT_NODE_COMMENT(ctx, node, "LAnd (true)");
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
      PRINT_NODE_COMMENT(ctx, node, "LOr (eval lhs)");
      Generate(ctx, node->lhs, 0);
      InsnLabelAutoL(ctx, "jnz", label_true);
      PRINT_NODE_COMMENT(ctx, node, "LOr (eval rhs)");
      Generate(ctx, node->rhs, 0);
      InsnLabelAutoL(ctx, "jnz", label_true);
      PRINT_NODE_COMMENT(ctx, node, "LOr (false)");
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
    PRINT_NODE_COMMENT(ctx, node, "And");
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "and");
    break;
  case kNodeXor:
    PRINT_NODE_COMMENT(ctx, node, "Xor");
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "xor");
    break;
  case kNodeOr:
    PRINT_NODE_COMMENT(ctx, node, "Or");
    Generate(ctx, node->lhs, 0);
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "or");
    break;
  case kNodeNot:
    PRINT_NODE_COMMENT(ctx, node, "Not");
    Generate(ctx, node->rhs, 0);
    Insn(ctx, "not");
    break;
  case kNodeRShift:
  case kNodeLShift:
    PRINT_NODE_COMMENT(ctx, node, "R/LShift");
    Generate(ctx, node->rhs, 0);
    Generate(ctx, node->lhs, 0);
    Insn(ctx, node->kind == kNodeRShift ? "sar" : "shl");
    break;
  case kNodeCall:
    {
      PRINT_NODE_COMMENT(ctx, node, "Call");
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
  case kNodeCast:
    Generate(ctx, node->rhs, lval);
    node->type = node->lhs->type;
    break;
  case kNodeVoid:
    break;
  case kNodeExprEnd:
    fprintf(stderr, "kNodeExprEnd must not be used\n");
    exit(1);
    break;
  case kNodeDefFunc:
    {
      ctx->scope = EnterScope(ctx->scope);

      struct Token *func_name = node->token;
      AddLabelToken(ctx, func_name);

      ctx->is_isr = 0;
      if (strncmp(func_name->raw, "_ISR", 4) == 0) {
        ctx->is_isr = 1;
      }

      InsnReg(ctx, "cpush", "fp");
      ctx->lvar_offset = 0;
      for (struct Node *param = node->cond; param; param = param->next) {
        struct Symbol *sym = NewSymbol(kSymLVar, param->lhs->token);
        sym->offset = ctx->lvar_offset;
        sym->type = param->type;
        assert(sym->type);
        AppendSymbol(ctx->scope->syms, sym);
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
        Insn(ctx, ctx->is_isr ? "iret" : "ret");
      }

      ctx->scope = LeaveScope(ctx->scope);
    }
    break;
  case kNodeBlock:
    ctx->scope = EnterScope(ctx->scope);

    for (struct Node *n = node->next; n; n = n->next) {
      Generate(ctx, n, 0);
    }

    ctx->scope = LeaveScope(ctx->scope);
    break;
  case kNodeReturn:
    if (node->lhs) {
      Generate(ctx, node->lhs, 0);
    }
    InsnReg(ctx, "cpop", "fp");
    Insn(ctx, ctx->is_isr ? "iret" : "ret");
    break;
  case kNodeDefVar:
    {
      int is_global = ctx->scope->parent == NULL;
      struct Symbol *sym;
      if (is_global) {
        sym = FindSymbol(ctx->scope, node->lhs->token);
      } else {
        sym = NewSymbol(kSymLVar, node->lhs->token);
        assert(node->type);
        sym->type = node->type;
        AppendSymbol(ctx->scope->syms, sym);
      }
      assert(sym->type);

      size_t mem_size = (SizeofType(sym->type) + 1) & ~((size_t)1);
      if (is_global) {
        assert(sym->offset != 0);
      } else {
        sym->offset = ctx->lvar_offset;
        ctx->lvar_offset += mem_size;

        if (node->rhs) {
          Generate(ctx, node->rhs, 0);
          if (SizeofType(sym->type) == 1) {
            InsnBaseOff(ctx, "st.1", "cstack", sym->offset);
          } else {
            InsnBaseOff(ctx, "st", "cstack", sym->offset);
          }
        }
      }
    }
    break;
  case kNodeIf:
    {
      int label_else = node->rhs ? GenLabel(ctx) : -1;
      int label_end = GenLabel(ctx);
      PRINT_NODE_COMMENT(ctx, node, "If (cond eval)");
      Generate(ctx, node->cond, 0);
      PRINT_NODE_COMMENT(ctx, node, "If (cond to bool)");
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", node->rhs ? label_else : label_end);
      PRINT_NODE_COMMENT(ctx, node, "If (then)");
      Generate(ctx, node->lhs, 0);
      if (node->rhs) {
        InsnLabelAutoL(ctx, "jmp", label_end);
        PRINT_NODE_COMMENT(ctx, node, "If (else)");
        AddLabelAutoL(ctx, label_else);
        Generate(ctx, node->rhs, 0);
      }
      PRINT_NODE_COMMENT(ctx, node, "If (end)");
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

      PRINT_NODE_COMMENT(ctx, node, "For (eval init)");
      Generate(ctx, node->lhs, 0);
      AddLabelAutoL(ctx, label_cond);
      Generate(ctx, node->cond, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_end);
      Generate(ctx, node->rhs, 0);
      AddLabelAutoL(ctx, label_next);
      Generate(ctx, node->lhs->next, 0);
      InsnLabelAutoL(ctx, "jmp", label_cond);
      PRINT_NODE_COMMENT(ctx, node, "For (end)");
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

      PRINT_NODE_COMMENT(ctx, node, "While");
      AddLabelAutoL(ctx, label_cond);
      Generate(ctx, node->cond, 0);
      InsnInt(ctx, "push", 0);
      Insn(ctx, "neq");
      InsnLabelAutoL(ctx, "jz", label_end);
      Generate(ctx, node->rhs, 0);
      InsnLabelAutoL(ctx, "jmp", label_cond);
      PRINT_NODE_COMMENT(ctx, node, "While (end)");
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
  case kNodeAsm:
    {
      struct AsmLine *l = GenAsmLine(ctx, kAsmLineRaw);
      l->raw[0] = INDENT[0];
      int len = 1;
      struct Token *t = node->lhs->token;
      while (t->kind == kTokenString) {
        len += DecodeStringLiteral(l->raw + len, sizeof(l->raw) - len, t);
        t = t->next;
      }
    }
    break;
  }
}

int main(int argc, char **argv) {
  int print_ast = 0;
  const char *input_filename = NULL;
  const char *output_filename = "a.s";

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--ast") == 0) {
      print_ast = 1;
    } else if (strcmp(argv[i], "-o") == 0) {
      i++;
      if (i >= argc) {
        fprintf(stderr, "output file name is not specified\n");
        exit(1);
      }
      output_filename = argv[i];
    } else if (input_filename) {
      fprintf(stderr, "multiple inputs are not supported: '%s'\n", argv[i]);
      exit(1);
    } else {
      input_filename = argv[i];
    }
  }

  if (input_filename == NULL) {
    fprintf(stderr, "no input file\n");
    exit(1);
  }

  FILE *input_file = stdin;
  FILE *output_file = stdout;
  if (strcmp(input_filename, "-") != 0) {
    input_file = fopen(input_filename, "r");
  }
  if (strcmp(output_filename, "-") != 0) {
    output_file = fopen(output_filename, "w");
  }

  src = malloc(1024);
  size_t src_len = fread(src, 1, 1023, input_file);
  src[src_len] = '\0';
  if (input_file != stdin) {
    fclose(input_file);
  }

  struct ParseContext parse_ctx = {
    NewSymbol(kSymHead, NULL)
  };

  Tokenize(src);
  struct Node *ast = Program(&parse_ctx);
  Expect(kTokenEOF);

  if (print_ast) {
    char ast_filename[256];
    if (strcmp(input_filename, "-") == 0) {
      strcpy(ast_filename, "stdin.ast");
    } else {
      snprintf(ast_filename, sizeof(ast_filename), "%s.ast", input_filename);
    }
    FILE *ast_file = fopen(ast_filename, "w");
    for (struct Node *n = ast; n; n = n->next) {
      PrintNode(ast_file, n, 0, NULL);
    }
    fclose(ast_file);
  }

  struct GenContext gen_ctx = {
    NewGlobalScope(parse_ctx.global_syms),
    2, 0, 0, 0, {}, {-1, -1}, 0, {}, print_ast, 0
  };
  int gvar_offset = 0x100;

  struct Instruction *insn_add_fp = InsnRegInt(&gen_ctx, "add", "fp", 0);
  for (struct Symbol *sym = gen_ctx.scope->syms->next; sym; sym = sym->next) {
    if (sym->kind == kSymGVar && sym->def->rhs) {
      size_t mem_size = (SizeofType(sym->type) + 1) & ~((size_t)1);
      sym->offset = gvar_offset;
      gvar_offset += mem_size;
      InsnBaseOff(&gen_ctx, "st", "zero", sym->offset);
    }
  }
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
    } else if (n->kind == kNodeDefVar) {
      Generate(&gen_ctx, n, 0);
    }
  }
  insn_add_fp->operands[1].val_int = gvar_offset;

  for (int i = 0; i < gen_ctx.num_line; i++) {
    struct AsmLine *line = gen_ctx.asm_lines + i;
    switch (line->kind) {
    case kAsmLineDeleted:
      break; // 何もしない
    case kAsmLineLabel:
      PrintLabel(output_file, &line->label);
      fprintf(output_file, ":\n");
      break;
    case kAsmLineInsn:
      fprintf(output_file, INDENT "%s", line->insn.opcode);
      for (int opr_i = 0;
           opr_i < MAX_OPERANDS && line->insn.operands[opr_i].kind != kOprNone;
           opr_i++) {
        struct Operand *opr = line->insn.operands + opr_i;
        fputc(" ,"[opr_i > 0], output_file);
        switch (opr->kind) {
        case kOprNone:
          // pass
        case kOprInt:
          fprintf(output_file, "%d", opr->val_int);
          break;
        case kOprLabel:
          PrintLabel(output_file, &opr->val_label);
          break;
        case kOprReg:
          fprintf(output_file, "%s", opr->val_reg);
          break;
        case kOprBaseOff:
          if (opr->val_base_off.base) {
            fprintf(output_file, "%s+", opr->val_base_off.base);
          }
          fprintf(output_file, "%d", opr->val_base_off.offset);
          break;
        }
      }
      fprintf(output_file, "\n");
      break;
    case kAsmLineIndentedComment:
      fprintf(output_file, INDENT "; %s\n", line->comment);
      break;
    case kAsmLineRaw:
      fprintf(output_file, "%s\n", line->raw);
      break;
    }
  }

  for (int i = 0; i < gen_ctx.num_strings; i++) {
    struct Token *tk_str = gen_ctx.strings[i];
    char buf[256];
    fprintf(output_file, "STR_%d: \n" INDENT "db ", i);

    while (tk_str->kind == kTokenString) {
      int len = DecodeStringLiteral(buf, sizeof(buf), tk_str);
      for (int i = 0; i < len; i++) {
        fprintf(output_file, "0x%02x,", buf[i]);
      }
      tk_str = tk_str->next;
    }
    fprintf(output_file, "0\n");
  }

  if (output_file != stdout) {
    fclose(output_file);
  }

  return 0;
}
