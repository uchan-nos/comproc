#pragma once

#include <stdio.h>
#include "token.h"

#define MAX_OPERANDS 3

enum LabelKind {
  kLabelToken, // 関数名など、コンパイル対象コードに現れるラベル
  kLabelAutoL, // 自動生成されたジャンプ用ラベル
  kLabelAutoS, // 自動生成された文字列リテラル用ラベル
  kLabelStr,   // 文字列リテラルで表現されるラベル
};

struct Label {
  enum LabelKind kind;
  union {
    struct Token *token;
    int label_no;
    const char *label_str;
  };
};

void PrintLabel(FILE *out, struct Label *label);

enum OperandKind {
  kOprNone, // オペランド末尾を示すマーカー
  kOprInt,
  kOprLabel,
  kOprReg,
  kOprBaseOff,
};

struct Operand {
  enum OperandKind kind;
  union {
    int val_int;
    struct Label val_label;
    const char *val_reg;
    struct {
      const char *base;
      int offset;
    } val_base_off;
  };
};

struct Instruction {
  const char *opcode;
  struct Operand operands[MAX_OPERANDS];
};

void SetInsnNoOpr(struct Instruction *insn, const char *opcode);

enum AsmLineKind {
  kAsmLineDeleted,
  kAsmLineInsn,
  kAsmLineLabel,
};

struct AsmLine {
  enum AsmLineKind kind;
  union {
    struct Label label;
    struct Instruction insn;
  };
};

void OptimizeAsmLines(struct AsmLine *lines, int num_lines);
