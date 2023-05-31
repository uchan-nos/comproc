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

void SetInsnNoOpr(struct Instruction *insn, const char *opcode) {
  insn->opcode = opcode;
  for (int i = 0; i < MAX_OPERANDS; i++) {
    insn->operands[i].kind = kOprNone;
  }
}

struct Instruction *GetInsn(struct AsmLine *lines, int num_lines, int i) {
  if (i < num_lines && lines[i].kind == kAsmLineInsn) {
    return &lines[i].insn;
  } else {
    return NULL;
  }
}

#define GET_INSN(i) GetInsn(lines, num_lines, i)
typedef struct Instruction Insn;

static int CollapsePushAndLoadStore(Insn *insn1, Insn *insn2, Insn *insn3) {
  if (strcmp(insn1->opcode, "push") != 0 || insn1->operands[0].kind != kOprBaseOff) {
    return 0;
  }

  if (insn2 && strcmp(insn2->opcode, "ldd") == 0) {
    insn1->opcode = "ld";
    return 1;
  } else if (insn2 && strcmp(insn2->opcode, "sta") == 0) {
    insn1->opcode = "st";
    if (insn3 && strcmp(insn3->opcode, "pop") == 0) {
      return 2;
    } else {
      return 1;
    }
  }
  return 0;
}

void OptimizeAsmLines(struct AsmLine *lines, int num_lines) {
  for (int i = 0; i < num_lines; i++) {
    struct Instruction *insn1 = GET_INSN(i);
    if (insn1 == NULL) {
      continue;
    }

    struct Instruction *insn2 = GET_INSN(i + 1);
    struct Instruction *insn3 = GET_INSN(i + 2);

    int delete_lines = CollapsePushAndLoadStore(insn1, insn2, insn3);
    for (int j = 0; j < delete_lines; j++) {
      lines[i + 1 + j].kind = kAsmLineDeleted;
    }
    i += delete_lines;
  }
}
