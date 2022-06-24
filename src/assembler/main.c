#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_OPERAND 128
#define ORIGIN 0x200

// line をニーモニックとオペランドに分割する
// 戻り値: オペランドの数
int SplitOpcode(char *line, char **label, char **mnemonic, char **operands, int n) {
  char *colon = strchr(line, ':');
  if (colon) {
    *label = line;
    *colon = '\0';
    line = colon + 1;
  } else {
    *label = NULL;
  }

  if ((*mnemonic = strtok(line, " \t\n")) == NULL) {
    return -1;
  }
  for (int i = 0; i < n; ++i) {
    if ((operands[i] = strtok(NULL, ",\n")) == NULL) {
      return i;
    }
    operands[i] += strspn(operands[i], " \t");
  }
  return n;
}

// 文字列をすべて小文字にする
void ToLower(char *s) {
  while (*s) {
    *s = tolower(*s);
    s++;
  }
}

struct LabelAddr {
  const char *label;
  int pc;
};

enum BPType {
  BP_PC_REL8,
  BP_ABS8,
  BP_ABS15,
};

struct Backpatch {
  int pc;
  const char *label;
  enum BPType type;
};

void InitBackpatch(struct Backpatch *bp,
                   int pc, const char *label, enum BPType type) {
  bp->pc = pc;
  bp->label = label;
  bp->type = type;
}

// i 番目のオペランドを文字列として取得
char *GetOperand(char *mnemonic, char **operands, int n, int i) {
  if (n <= i) {
    fprintf(stderr, "too few operands for '%s': %d\n", mnemonic, n);
    exit(1);
  }
  return operands[i];
}

// i 番目のオペランドを long 値として取得
long GetOperandLong(char *operand, struct Backpatch *backpatches,
                    int *num_backpatches, int pc, enum BPType bp_type) {
  char *endptr;
  long value = strtol(operand, &endptr, 0);

  if (endptr == operand) {
    InitBackpatch(backpatches + *num_backpatches, pc, strdup(operand), bp_type);
    (*num_backpatches)++;
    return 0;
  } else if (*endptr) {
    fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
    exit(1);
  }

  return value;
}

#define GET_STR(i) GetOperand((mnemonic), (operands), (num_opr), (i))
#define GET_LONG(i, bp_type) GetOperandLong(\
    GetOperand((mnemonic), (operands), (num_opr), (i)), \
    (backpatches), &(num_backpatches), (pc), (bp_type))

// db 命令のオペランドを解釈し、メモリに書き、バイト数を返す
int DataByte(uint16_t *insn, char **operands, int num_opr) {
  char *endptr;
  for (int i = 0; i < num_opr / 2; i++) {
    uint16_t v = strtol(operands[2 * i], &endptr, 0);
    if (*endptr) {
      fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
      exit(1);
    }
    v |= strtol(operands[2 * i + 1], &endptr, 0) << 8;
    if (*endptr) {
      fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
      exit(1);
    }
    insn[i] = v;
  }
  if (num_opr % 2) {
    insn[num_opr / 2] = strtol(operands[num_opr - 1], &endptr, 0);
    if (*endptr) {
      fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
      exit(1);
    }
  }
  return num_opr;
}

int main(void) {
  char line[256];
  char *label;
  char *mnemonic;
  char *operands[MAX_OPERAND];

  uint16_t insn[512];
  int pc = ORIGIN;

  struct Backpatch backpatches[128];
  int num_backpatches = 0;

  struct LabelAddr labels[128];
  int num_labels = 0;

  while (fgets(line, sizeof(line), stdin) != NULL) {
    int num_opr = SplitOpcode(line, &label, &mnemonic, operands, MAX_OPERAND);

    if (label) {
      labels[num_labels].label = strdup(label);
      labels[num_labels].pc = pc;
      num_labels++;
    }

    if (num_opr < 0) {
      continue;
    }
    ToLower(mnemonic);

    char *sep = strchr(mnemonic, '.');
    char *postfix = NULL;
    if (sep) {
      postfix = sep + 1;
      *sep = '\0';
    }

    if (strcmp(mnemonic, "push") == 0) {
      insn[pc >> 1] = GET_LONG(0, BP_ABS15) & 0x7fffu;
    } else if (strcmp(mnemonic, "pop") == 0) {
      insn[pc >> 1] = 0x8100;
    } else if (strcmp(mnemonic, "dup") == 0) {
      long n = GET_LONG(0, BP_ABS8);
      if (n != 0 && n != 1) {
        fprintf(stderr, "DUP takes 0 or 1: %ld\n", n);
        exit(1);
      }
      insn[pc >> 1] = 0x8200 | n;
    } else if (strcmp(mnemonic, "ld") == 0) {
      insn[pc >> 1] = 0x9000 | (uint8_t)GET_LONG(0, BP_ABS8);
    } else if (strcmp(mnemonic, "ldd") == 0) {
      insn[pc >> 1] = 0x9100;
    } else if (strcmp(mnemonic, "st") == 0) {
      insn[pc >> 1] = 0x9400 | (uint8_t)GET_LONG(0, BP_ABS8);
    } else if (strcmp(mnemonic, "sta") == 0) { // store, remaining address
      insn[pc >> 1] = 0x9500;
    } else if (strcmp(mnemonic, "std") == 0) { // store, remaining data
      insn[pc >> 1] = 0x9600;
    } else if (strcmp(mnemonic, "add") == 0) {
      insn[pc >> 1] = 0xb002;
    } else if (strcmp(mnemonic, "sub") == 0) {
      insn[pc >> 1] = 0xb003;
    } else if (strcmp(mnemonic, "mul") == 0) {
      insn[pc >> 1] = 0xb004;
    } else if (strcmp(mnemonic, "join") == 0) {
      insn[pc >> 1] = 0xb005;
    } else if (strcmp(mnemonic, "lt") == 0) {
      insn[pc >> 1] = 0xb008;
    } else if (strcmp(mnemonic, "eq") == 0) {
      insn[pc >> 1] = 0xb009;
    } else if (strcmp(mnemonic, "neq") == 0) {
      insn[pc >> 1] = 0xb00a;
    } else if (strcmp(mnemonic, "and") == 0) {
      insn[pc >> 1] = 0xb010;
    } else if (strcmp(mnemonic, "xor") == 0) {
      insn[pc >> 1] = 0xb011;
    } else if (strcmp(mnemonic, "or") == 0) {
      insn[pc >> 1] = 0xb012;
    } else if (strcmp(mnemonic, "not") == 0) {
      insn[pc >> 1] = 0xb113;
    } else if (strcmp(mnemonic, "shr") == 0) {
      insn[pc >> 1] = 0xb014;
    } else if (strcmp(mnemonic, "shl") == 0) {
      insn[pc >> 1] = 0xb015;
    } else if (strcmp(mnemonic, "sar") == 0) {
      insn[pc >> 1] = 0xb016;
    } else if (strcmp(mnemonic, "jmp") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    pc, strdup(GET_STR(0)), BP_PC_REL8);
      insn[pc >> 1] = 0xa000;
    } else if (strcmp(mnemonic, "jz") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    pc, strdup(GET_STR(0)), BP_PC_REL8);
      insn[pc >> 1] = 0xa100;
    } else if (strcmp(mnemonic, "jnz") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    pc, strdup(GET_STR(0)), BP_PC_REL8);
      insn[pc >> 1] = 0xa200;
    } else if (strcmp(mnemonic, "call") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    pc, strdup(GET_STR(0)), BP_PC_REL8);
      insn[pc >> 1] = 0xa300;
    } else if (strcmp(mnemonic, "ret") == 0) {
      insn[pc >> 1] = 0xa400 | (uint8_t)GET_LONG(0, BP_ABS8);
    } else if (strcmp(mnemonic, "db") == 0) {
      pc += DataByte(&insn[pc >> 1], operands, num_opr);
      if (pc & 1) {
        pc++;
      }
      continue;
    } else {
      fprintf(stderr, "unknown mnemonic: %s\n", mnemonic);
      exit(1);
    }

    if (0x9000 <= insn[pc >> 1] && insn[pc >> 1] < 0xa000) {
      if (postfix && strcmp(postfix, "1") == 0) {
        insn[pc >> 1] |= 0x0800;
      }
    }

    pc += 2;
  }

  for (int i = 0; i < num_backpatches; i++) {
    int l = 0;
    for (; l < num_labels; l++) {
      if (strcmp(backpatches[i].label, labels[l].label)) {
        continue;
      }

      int ins_pc = backpatches[i].pc;
      uint16_t ins = insn[ins_pc >> 1];
      switch (backpatches[i].type) {
      case BP_PC_REL8:
        ins = (ins & 0xff00u) | (uint8_t)((labels[l].pc - ins_pc) >> 1);
        break;
      case BP_ABS8:
        ins = (ins & 0xff00u) | (uint8_t)labels[l].pc;
        break;
      case BP_ABS15:
        ins = (ins & 0x8000u) | (labels[l].pc & 0x7fffu);
        break;
      }
      insn[ins_pc >> 1] = ins;
      break;
    }
    if (l == num_labels) {
      fprintf(stderr, "unknown label: %s\n", backpatches[i].label);
      exit(1);
    }
  }

  for (int i = ORIGIN; i < pc; i += 2) {
    printf("%04X\n", insn[i >> 1]);
  }
  return 0;
}
