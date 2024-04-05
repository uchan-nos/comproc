#include "insn.h"

#include <string.h>

void PrintLabel(FILE *out, struct Label *label) {
  switch (label->kind) {
  case kLabelToken:
    fprintf(out, "%.*s", label->token->len, label->token->raw);
    break;
  case kLabelAutoL:
    fprintf(out, "L_%d", label->label_no);
    break;
  case kLabelAutoS:
    fprintf(out, "STR_%d", label->label_no);
    break;
  case kLabelStr:
    fprintf(out, "%s", label->label_str);
    break;
  }
}

void SetInsnNoOpr(struct Instruction *insn,
                  enum InsnKind kind, const char *opcode) {
  insn->kind = kind;
  insn->opcode = opcode;
  for (int i = 0; i < MAX_OPERANDS; i++) {
    insn->operands[i].kind = kOprNone;
  }
}
