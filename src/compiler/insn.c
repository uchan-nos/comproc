#include "insn.h"

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

void SetInsnNoOpr(struct Instruction *insn, const char *opcode) {
  insn->opcode = opcode;
  for (int i = 0; i < MAX_OPERANDS; i++) {
    insn->operands[i].kind = kOprNone;
  }
}

/*
void SetInsnInt(struct Instruction *insn, const char *opcode, int operand1) {
  SetInsnNoOpr(insn, opcode);
  insn->operands[0].kind = kOprInt;
  insn->operands[0].val_int = operand1;
}

void SetInsnBaseOff(struct Instruction *insn, const char *opcode,
                    const char *base, int offset) {
  SetInsnNoOpr(insn, opcode);
  insn->operands[0].kind = kOprBaseOff;
  insn->operands[0].val_base_off.base = base;
  insn->operands[0].val_base_off.offset = offset;
}

void SetInsnLabel(struct Instruction *insn, const char *opcode,
                  struct Token *label_token) {
  SetInsnNoOpr(insn, opcode);
  insn->operands[0].kind = kOprLabel;
  insn->operands[0].val_label.kind = kLabelToken;
  insn->operands[0].val_label.token = label_token;
}

void SetInsnAutoLabel(struct Instruction *insn, const char *opcode,
                      int label_no) {
  SetInsnNoOpr(insn, opcode);
  insn->operands[0].kind = kOprLabel;
  insn->operands[0].val_label.kind = kLabelAuto;
  insn->operands[0].val_label.label_no = label_no;
}
*/
