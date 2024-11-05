#include "ast.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "symbol.h"
#include "token.h"

struct Type *TYPE_INT;

void Locate(char *p);

struct Node *NewNode(enum NodeKind kind, struct Token *token) {
  static int last_index = 0;
  struct Node *n = malloc(sizeof(struct Node));
  n->kind = kind;
  n->index = last_index++;
  n->token = token;
  n->next = n->lhs = n->rhs = n->cond = NULL;
  n->type = NULL;
  n->scope = NULL;
  return n;
}

struct Node *NewNodeInteger(struct Token *token) {
  struct Node *n = NewNode(kNodeInteger, token);
  n->type = TYPE_INT;
  return n;
}

struct Node *NewNodeBinOp(enum NodeKind kind, struct Token *op,
                          struct Node *lhs, struct Node *rhs) {
  struct Node *n = NewNode(kind, op);
  n->lhs = lhs;
  n->rhs = rhs;
  return n;
}

struct Type *DecideBinOpType(struct Type *lhs, struct Type *rhs) {
  struct Type *t = NULL;
  if (lhs->kind == kTypeChar && rhs->kind == kTypeChar) {
    t = TYPE_INT;
  } else if (lhs->kind == kTypeChar) { // rhs は int
    t = rhs;
  } else if (rhs->kind == kTypeChar) { // lhs は int
    t = lhs;
  } else { // 両辺が int
    if (lhs->attr & TYPE_ATTR_SIGNED) {
      // lhs が signed のとき、全体の型は rhs の signed/unsigned により決まる
      t = rhs;
    } else {
      // lhs が unsigned のとき、全体の型は unsigned になる
      t = lhs;
    }
  }
  return t;
}

struct Node *Program(struct ParseContext *ctx) {
  TYPE_INT = NewType(kTypeInt);
  TYPE_INT->attr = TYPE_ATTR_SIGNED;

  struct Node *head = ExternalDeclaration(ctx);
  struct Node *n = head;
  while (n) {
    n->next = ExternalDeclaration(ctx);
    n = n->next;
  }
  return head;
}

struct Node *ExternalDeclaration(struct ParseContext *ctx) {
  struct Node *tspec = TypeSpec();

  if (!tspec) {
    return NULL;
  }

  struct Token *id = Expect(kTokenId);
  if (Consume('(')) {
    return FunctionDefinition(ctx, tspec, id);
  } else {
    return VariableDefinition(ctx, tspec, id);
  }
}

struct Node *FunctionDefinition(struct ParseContext *ctx,
                                struct Node *tspec, struct Token *id) {
  struct Node *func_def = NewNode(kNodeDefFunc, id);
  func_def->lhs = tspec;

  struct Symbol *func_sym = NewSymbol(kSymFunc, id);
  func_sym->def = func_def;
  AppendSymbol(ctx->scope->syms, func_sym);

  ctx->scope = EnterScope(ctx->scope);
  func_def->scope = ctx->scope;

  struct Node *params = ParameterList();
  Expect(')');
  for (struct Node *param = params; param; param = param->next) {
    struct Symbol *sym = NewSymbol(kSymLVar, param->lhs->token);
    sym->type = param->type;
    sym->offset = ctx->scope->var_offset;
    ctx->scope->var_offset += 2;
    AppendSymbol(ctx->scope->syms, sym);
  }
  func_def->cond = params;

  struct Node *func_body = Block(ctx);
  func_def->rhs = func_body;

  // void 関数で、最後が return で終わっていなければ追加
  if (tspec->type->kind == kTypeVoid) {
    struct Node *last_node = func_body->rhs;
    if (last_node) {
      while (last_node->next) {
        last_node = last_node->next;
      }
      if (last_node->kind != kNodeReturn) {
        last_node->next = NewNode(kNodeReturn, NULL);
      }
    } else {
      func_body->rhs = NewNode(kNodeReturn, NULL);
    }
  }

  ctx->scope = ctx->scope->parent;
  return func_def;
}

struct Node *VariableDefinition(struct ParseContext *ctx,
                                struct Node *tspec, struct Token *id) {
  struct Node *def = NewNode(kNodeDefVar, tspec->token);
  def->type = tspec->type;
  def->lhs = NewNode(kNodeId, id);

  if (Consume('[')) {
    struct Token *len = Expect(kTokenInteger);
    Expect(']');
    struct Type *t = NewType(kTypeArray);
    t->len = len->value.as_int;
    t->base = def->type;
    def->type = t;
  }

  assert(ctx->scope->syms);
  assert(def->type);
  struct Symbol *sym = NewSymbol(ctx->scope->parent ? kSymLVar : kSymGVar, id);
  sym->def = def;
  sym->type = def->type;
  sym->offset = ctx->scope->var_offset;

  int attr_at = 0;
  if (Consume(kTokenAttr)) {
    struct Token *attr;
    Expect('(');
    Expect('(');
    if ((attr = Consume(kTokenId))) {
      if (strncmp(attr->raw, "at", attr->len) == 0) {
        if (sym->kind != kSymGVar) {
          fprintf(stderr, "'at' attribute can only be used with global variables\n");
          Locate(attr->raw);
          exit(1);
        }
        sym->attr |= SYM_ATTR_FIXED_ADDR;

        Expect('(');
        struct Token *addr = Expect(kTokenInteger);
        sym->offset = addr->value.as_int;
        Expect(')');
        attr_at = 1;
      } else {
        fprintf(stderr, "unknown attribute\n");
        Locate(attr->raw);
        exit(1);
      }
    }
    Expect(')');
    Expect(')');
  }

  if (!attr_at) {
    size_t mem_size = (SizeofType(def->type) + 1) & ~((size_t)1);
    ctx->scope->var_offset += mem_size;
  }
  AppendSymbol(ctx->scope->syms, sym);

  if (Consume('=')) {
    def->rhs = Expression(ctx);
  }
  Expect(';');

  return def;
}

struct Node *Block(struct ParseContext *ctx) {
  struct Token *brace = Consume('{');
  if (brace == NULL) {
    return NULL;
  }

  struct Node *block = NewNode(kNodeBlock, brace);
  block->scope = ctx->scope;

  struct Node *node = block;
  while (Consume('}') == NULL) {
    if ((node->next = InnerDeclaration(ctx))) {
    } else if ((node->next = Statement(ctx))) {
    } else {
      fprintf(stderr, "either declaration or statement is expected\n");
      Locate(cur_token->raw);
      exit(1);
    }

    node = node->next;
  }
  block->rhs = block->next;
  block->next = NULL;

  return block;
}

struct Node *InnerDeclaration(struct ParseContext *ctx) {
  struct Node *ed = ExternalDeclaration(ctx);
  if (ed == NULL) {
    return NULL;
  }
  if (ed->kind == kNodeDefFunc) {
    fprintf(stderr, "inner func is not allowed\n");
    Locate(ed->token->raw);
    exit(1);
  }
  return ed;
}

struct Node *Statement(struct ParseContext *ctx) {
  struct Token *token;

  if ((token = Consume(kTokenReturn))) {
    struct Node *ret = NewNode(kNodeReturn, token);
    ret->lhs = Expression(ctx);
    Expect(';');
    return ret;
  }

  if ((token = Consume(kTokenIf))) {
    struct Node *if_ = NewNode(kNodeIf, token);
    Expect('(');
    if_->cond = Expression(ctx);
    Expect(')');
    if_->lhs = Statement(ctx);

    if ((token = Consume(kTokenElse))) {
      if_->rhs = Statement(ctx);
    }

    return if_;
  }

  if ((token = Consume(kTokenFor))) {
    struct Node *for_ = NewNode(kNodeFor, token);
    Expect('(');
    for_->lhs = InitStatement(ctx);
    for_->cond = Expression(ctx);
    Expect(';');
    for_->lhs->next = Expression(ctx);
    Expect(')');
    for_->rhs = Statement(ctx);

    return for_;
  }

  if ((token = Consume(kTokenWhile))) {
    struct Node *while_ = NewNode(kNodeWhile, token);
    Expect('(');
    while_->cond = Expression(ctx);
    Expect(')');
    while_->rhs = Statement(ctx);

    return while_;
  }

  if ((token = Consume(kTokenBreak))) {
    Expect(';');
    return NewNode(kNodeBreak, token);
  }

  if ((token = Consume(kTokenContinue))) {
    Expect(';');
    return NewNode(kNodeContinue, token);
  }

  if (cur_token->kind == '{') {
    ctx->scope = EnterScope(ctx->scope);
    ctx->scope->var_offset = ctx->scope->parent->var_offset;
    struct Node *block = Block(ctx);
    ctx->scope = ctx->scope->parent;
    return block;
  }

  if ((token = Consume(kTokenAsm))) {
    struct Node *asm_ = NewNode(kNodeAsm, token);
    Expect('(');
    asm_->lhs = NewNode(kNodeString, Expect(kTokenString));
    while (Consume(kTokenString));
    Expect(')');
    Expect(';');
    return asm_;
  }

  struct Node *e = Expression(ctx);
  Expect(';');

  return e;
}

struct Node *InitStatement(struct ParseContext *ctx) {
  struct Node *n = InnerDeclaration(ctx);
  if (n == NULL) {
    n = Expression(ctx);
    Expect(';');
  }
  return n;
}

struct Node *Expression(struct ParseContext *ctx) {
  return Assignment(ctx);
}

struct Node *Assignment(struct ParseContext *ctx) {
  struct Node *node = LogicalOr(ctx);

  struct Token *op;
  if ((op = Consume('='))) {
    node = NewNodeBinOp(kNodeAssign, op, node, Assignment(ctx));
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenCompAssign + '+'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeAdd, op, node, Assignment(ctx)));
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenCompAssign + '-'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeSub, op, node, Assignment(ctx)));
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenCompAssign + '|'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeOr, op, node, Assignment(ctx)));
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenCompAssign + '^'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeXor, op, node, Assignment(ctx)));
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenCompAssign + '&'))) {
    node = NewNodeBinOp(kNodeAssign, op, node,
                        NewNodeBinOp(kNodeAnd, op, node, Assignment(ctx)));
    node->type = node->lhs->type;
  }

  return node;
}

struct Node *LogicalOr(struct ParseContext *ctx) {
  struct Node *node = LogicalAnd(ctx);

  struct Token *op;
  if ((op = Consume(kTokenOr))) {
    node = NewNodeBinOp(kNodeLOr, op, node, LogicalOr(ctx));
  }

  return node;
}

struct Node *LogicalAnd(struct ParseContext *ctx) {
  struct Node *node = BitwiseOr(ctx);

  struct Token *op;
  if ((op = Consume(kTokenAnd))) {
    node = NewNodeBinOp(kNodeLAnd, op, node, LogicalAnd(ctx));
  }

  return node;
}

struct Node *BitwiseOr(struct ParseContext *ctx) {
  struct Node *node = BitwiseXor(ctx);

  struct Token *op;
  if ((op = Consume('|'))) {
    node = NewNodeBinOp(kNodeOr, op, node, BitwiseOr(ctx));
    node->type = DecideBinOpType(node->lhs->type, node->rhs->type);
  }

  return node;
}

struct Node *BitwiseXor(struct ParseContext *ctx) {
  struct Node *node = BitwiseAnd(ctx);

  struct Token *op;
  if ((op = Consume('^'))) {
    node = NewNodeBinOp(kNodeXor, op, node, BitwiseXor(ctx));
    node->type = DecideBinOpType(node->lhs->type, node->rhs->type);
  }

  return node;
}

struct Node *BitwiseAnd(struct ParseContext *ctx) {
  struct Node *node = Equality(ctx);

  struct Token *op;
  if ((op = Consume('&'))) {
    node = NewNodeBinOp(kNodeAnd, op, node, BitwiseAnd(ctx));
    node->type = DecideBinOpType(node->lhs->type, node->rhs->type);
  }

  return node;
}

struct Node *Equality(struct ParseContext *ctx) {
  struct Node *node = Relational(ctx);

  struct Token *op;
  if ((op = Consume(kTokenEq))) {
    node = NewNodeBinOp(kNodeEq, op, node, Equality(ctx));
    node->type = TYPE_INT;
  } else if ((op = Consume(kTokenNEq))) {
    node = NewNodeBinOp(kNodeNEq, op, node, Equality(ctx));
    node->type = TYPE_INT;
  }

  return node;
}

struct Node *Relational(struct ParseContext *ctx) {
  struct Node *node = BitwiseShift(ctx);

  struct Token *op;
  if ((op = Consume('<'))) {
    node = NewNodeBinOp(kNodeLT, op, node, Relational(ctx));
    node->type = TYPE_INT;
  } else if ((op = Consume('>'))) {
    node = NewNodeBinOp(kNodeLT, op, Relational(ctx), node);
    node->type = TYPE_INT;
  } else if ((op = Consume(kTokenLE))) {
    node = NewNodeBinOp(kNodeLE, op, node, Relational(ctx));
    node->type = TYPE_INT;
  } else if ((op = Consume(kTokenGE))) {
    node = NewNodeBinOp(kNodeLE, op, Relational(ctx), node);
    node->type = TYPE_INT;
  }

  return node;
}

struct Node *BitwiseShift(struct ParseContext *ctx) {
  struct Node *node = Additive(ctx);

  struct Token *op;
  if ((op = Consume(kTokenRShift))) {
    node = NewNodeBinOp(kNodeRShift, op, node, BitwiseShift(ctx));
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenLShift))) {
    node = NewNodeBinOp(kNodeLShift, op, node, BitwiseShift(ctx));
    node->type = node->lhs->type;
  }

  return node;
}

struct Node *Additive(struct ParseContext *ctx) {
  struct Node *node = Multiplicative(ctx);

  struct Token *op;
  while (1) {
    if ((op = Consume('+'))) {
      node = NewNodeBinOp(kNodeAdd, op, node, Multiplicative(ctx));
      if (node->lhs->type->kind == kTypePtr) {
        node->type = node->lhs->type;
      } else {
        node->type = DecideBinOpType(node->lhs->type, node->rhs->type);
      }
    } else if ((op = Consume('-'))) {
      node = NewNodeBinOp(kNodeSub, op, node, Multiplicative(ctx));
      if (node->lhs->type->kind == kTypePtr) {
        if (node->rhs->type->kind == kTypePtr) {
          node->type = TYPE_INT;
        } else {
          node->type = node->lhs->type;
        }
      } else {
        node->type = DecideBinOpType(node->lhs->type, node->rhs->type);
      }
    } else {
      break;
    }
  }

  return node;
}

struct Node *Multiplicative(struct ParseContext *ctx) {
  struct Node *node = Cast(ctx);

  struct Token *op;
  if ((op = Consume('*'))) {
    node = NewNodeBinOp(kNodeMul, op, node, Multiplicative(ctx));
    node->type = DecideBinOpType(node->lhs->type, node->rhs->type);
  }

  return node;
}

struct Node *Cast(struct ParseContext *ctx) {
  struct Token *origin = cur_token;

  struct Token *op = Consume('(');
  if (!op) {
    return Unary(ctx);
  }

  struct Node *tspec = TypeSpec();
  if (!tspec) {
    cur_token = origin;
    return Unary(ctx);
  }

  Expect(')');
  struct Node *node = NewNodeBinOp(kNodeCast, op, tspec, Cast(ctx));
  node->type = tspec->type;

  return node;
}

struct Node *Unary(struct ParseContext *ctx) {
  struct Node *node;

  struct Token *op;
  if ((op = Consume(kTokenInc))) {
    node = NewNodeBinOp(kNodeInc, op, NULL, Unary(ctx));
    node->type = node->rhs->type;
  } else if ((op = Consume(kTokenDec))) {
    node = NewNodeBinOp(kNodeDec, op, NULL, Unary(ctx));
    node->type = node->rhs->type;
  } else if ((op = Consume('&'))) {
    node = NewNodeBinOp(kNodeRef, op, NULL, Cast(ctx));
    node->type = NewType(kTypePtr);
    node->type->base = node->rhs->type;
  } else if ((op = Consume('*'))) {
    node = NewNodeBinOp(kNodeDeref, op, NULL, Cast(ctx));
    node->type = node->rhs->type->base;
  } else if ((op = Consume('-'))) {
    struct Token *zero_tk = NewToken(kTokenInteger, NULL, 0);
    zero_tk->value.as_int = 0;
    struct Node *zero = NewNodeInteger(zero_tk);
    node = NewNodeBinOp(kNodeSub, op, zero, Unary(ctx));
    node->type = node->rhs->type;
  } else if ((op = Consume('~'))) {
    node = NewNodeBinOp(kNodeNot, op, NULL, Cast(ctx));
    node->type = node->rhs->type;
  } else {
    node = Postfix(ctx);
  }

  return node;
}

struct Node *Postfix(struct ParseContext *ctx) {
  struct Node *node = Primary(ctx);

  struct Token *op;
  if ((op = Consume(kTokenInc))) {
    node = NewNodeBinOp(kNodeInc, op, node, NULL);
    node->type = node->lhs->type;
  } else if ((op = Consume(kTokenDec))) {
    node = NewNodeBinOp(kNodeDec, op, node, NULL);
    node->type = node->lhs->type;
  } else if ((op = Consume('['))) {
    struct Type *array_type = node->type;
    struct Node *ind = NewNodeBinOp(kNodeAdd, op, node, Expression(ctx));
    ind->type = array_type;
    Expect(']');

    node = NewNodeBinOp(kNodeDeref, op, NULL, ind);
    node->type = array_type->base;
  } else if ((op = Consume('('))) {
    struct Symbol *func = FindSymbol(ctx->scope, node->token);
    if (!func) {
      fprintf(stderr, "symbol not found\n");
      Locate(node->token->raw);
      exit(1);
    }
    node = NewNodeBinOp(kNodeCall, op, node, NULL);
    node->type = func->def->lhs->type; // 関数の戻り値型を取得
    if (!Consume(')')) {
      node->rhs = Expression(ctx);
      struct Node *arg = node->rhs;
      while (Consume(',')) {
        arg->next = Expression(ctx);
        arg = arg->next;
      }
      Expect(')');
    }
  }

  return node;
}

struct Node *Primary(struct ParseContext *ctx) {
  struct Node *node = NULL;
  struct Token *tk;
  if ((tk = Consume('('))) {
    node = Expression(ctx);
    Expect(')');
  } else if ((tk = Consume(kTokenInteger))) {
    node = NewNodeInteger(tk);
  } else if ((tk = Consume(kTokenCharacter))) {
    node = NewNodeInteger(tk);
  } else if ((tk = Consume(kTokenString))) {
    node = NewNode(kNodeString, tk);
    node->type = NewType(kTypePtr);
    node->type->base = NewType(kTypeChar);

    // 文字列リテラルが連続する区間は 1 つの kNodeString ノードが担当する
    while (Consume(kTokenString));
  } else if ((tk = Consume(kTokenId))) {
    struct Symbol *sym = FindSymbol(ctx->scope, tk);
    if (!sym) {
      fprintf(stderr, "symbol not found\n");
      Locate(tk->raw);
      exit(1);
    }
    node = NewNode(kNodeId, tk);
    node->type = sym->type;
  } else {
    node = NewNode(kNodeVoid, cur_token);
  }

  return node;
}

struct Node *TypeSpec() {
  struct Type *type = NULL;
  struct Token *token;

  // (un)signed が明示的に指定されたら 1
  int attr_signed = 0, attr_unsigned = 0;
  if ((token = Consume(kTokenSigned))) {
    attr_signed = 1;
  } else if ((token = Consume(kTokenUnsigned))) {
    attr_unsigned = 1;
  }

  if ((token = Consume(kTokenInt))) {
    type = NewType(kTypeInt);
  } else if ((token = Consume(kTokenChar))) {
    type = NewType(kTypeChar);
  } else if ((token = Consume(kTokenVoid))) {
    type = NewType(kTypeVoid);
  }

  if (!type) {
    if (attr_signed || attr_unsigned) {
      type = NewType(kTypeInt); // デフォルトで int
    } else {
      return NULL;
    }
  }

  if (attr_signed) {
    type->attr |= TYPE_ATTR_SIGNED;
  } else if (attr_unsigned) {
    // pass
  } else if (type->kind != kTypeChar) {
    type->attr |= TYPE_ATTR_SIGNED;
  }

  if (Consume('*')) {
    struct Type *t = NewType(kTypePtr);
    t->base = type;
    type = t;
  }

  struct Node *tspec = NewNode(kNodeTypeSpec, token);
  tspec->type = type;
  return tspec;
}

struct Node *ParameterList() {
  struct Node *tspec = TypeSpec();
  if (!tspec) {
    return NULL;
  }

  struct Node *param = NewNode(kNodePList, tspec->token);
  param->type = tspec->type;
  param->lhs = NewNode(kNodeId, Expect(kTokenId));
  struct Node *plist = param;

  while (Consume(',')) {
    tspec = TypeSpec();
    struct Node *p = NewNode(kNodePList, tspec->token);
    p->type = tspec->type;
    p->lhs = NewNode(kNodeId, Expect(kTokenId));
    param->next = p;
    param = param->next;
  }
  return plist;
}

static const char *node_kind_name[] = {
  "Integer",
  "Id",
  "Add",
  "Sub",
  "Mul",
  "Assign",
  "LT", // <
  "Inc",
  "Dec",
  "Eq",
  "NEq",
  "Ref",   // & exp
  "Deref", // * exp
  "LAnd",  // &&
  "LOr",   // ||
  "String",// string literal
  "And",   // &
  "Xor",   // ^
  "Or",    // |
  "Not",   // ~
  "RShift",// >>
  "LShift",// <<
  "Call",
  "ExprEnd",
  "DefFunc",
  "Block",
  "Return",
  "DefVar",
  "If",
  "For",
  "While",
  "Break",
  "Continue",
  "TypeSpec",
  "PList",
};

void PrintNode(FILE *out, struct Node *n, int indent, const char *key) {
  if (n == NULL) {
    fprintf(out, "%*snull\n", indent, "");
    return;
  }

  fprintf(out, "%*s", indent, "");
  indent += key ? strlen(key) : 0;
  if (key) {
    fprintf(out, "%s", key);
  }
  fprintf(out, "[%d %s token='%.*s' type=",
         n->index, node_kind_name[n->kind], n->token->len, n->token->raw);
  if (n->type) {
    PrintType(out, n->type);
  } else {
    fprintf(out, "null");
  }
  if (n->lhs == NULL && n->rhs == NULL && n->cond == NULL) {
    fprintf(out, "]\n");
    if (n->next) {
      PrintNode(out, n->next, indent, NULL);
    }
    return;
  }

  fprintf(out, "\n");
  if (n->lhs) {
    PrintNode(out, n->lhs, indent + 1, "lhs=");
  }
  if (n->cond) {
    PrintNode(out, n->cond, indent + 1, "cond=");
  }
  if (n->rhs) {
    PrintNode(out, n->rhs, indent + 1, "rhs=");
  }
  fprintf(out, "%*s] (%s)\n", indent, "", node_kind_name[n->kind]);

  if (n->next) {
    PrintNode(out, n->next, indent, NULL);
  }
}
