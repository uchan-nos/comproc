#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_OPERAND 128
#define ORIGIN 0x300

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
  int ip;
};

enum BPType {
  BP_IP_REL12,
  BP_IP_REL10,
  BP_ABS10,
  BP_ABS15,
};

struct Backpatch {
  int ip;
  const char *label;
  enum BPType type;
};

void InitBackpatch(struct Backpatch *bp,
                   int ip, const char *label, enum BPType type) {
  bp->ip = ip;
  bp->label = label;
  bp->type = type;
}

enum AddrBase {
  AB_ZERO,
  AB_FP,
  AB_IP,
  AB_CSTK,
};

// X+imm 形式のオペランドを読み取る
// 戻り値: X の種類を表す数値
enum AddrBase ParseAddrOffset(char *opr, uint16_t *off) {
  char *plus = strchr(opr, '+');
  char *off_s = opr;
  enum AddrBase ab = AB_ZERO;
  if (plus) {
    *plus = '\0';
    off_s = plus + 1;
    ToLower(opr);
    if (strcmp(opr, "z") == 0) {
      ab = AB_ZERO;
    } else if (strcmp(opr, "zero") == 0) {
      ab = AB_ZERO;
    } else if (strcmp(opr, "fp") == 0) {
      ab = AB_FP;
    } else if (strcmp(opr, "ip") == 0) {
      ab = AB_IP;
    } else if (strcmp(opr, "cs") == 0) {
      ab = AB_CSTK;
    } else if (strcmp(opr, "cstack") == 0) {
      ab = AB_CSTK;
    }
  }
  char *endptr;
  *off = strtol(off_s, &endptr, 0);

  if (*endptr) {
    fprintf(stderr, "failed to parse addr offset: '%s'\n", endptr);
    exit(1);
  }

  return ab;
}

int ExpectFP(char *opr) {
  ToLower(opr);
  if (strcmp(opr, "fp") != 0) {
    return -1;
  }
  return 0;
}

// i 番目のオペランドを文字列として取得
char *GetOperand(char *mnemonic, char **operands, int n, int i) {
  if (n <= i) {
    fprintf(stderr, "too few operands for '%s': %d\n", mnemonic, n);
    exit(1);
  }
  return operands[i];
}

// i 番目のオペランドを long 値として取得（整数変換できなければバックパッチ）
long GetOperandLong(char *operand, struct Backpatch *backpatches,
                    int *num_backpatches, int ip, enum BPType bp_type) {
  char *endptr;
  long value = strtol(operand, &endptr, 0);

  if (endptr == operand) {
    InitBackpatch(backpatches + *num_backpatches, ip, strdup(operand), bp_type);
    (*num_backpatches)++;
    return 0;
  } else if (*endptr) {
    fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
    exit(1);
  }

  return value;
}

// i 番目のオペランドを long 値として取得
long GetOperandLongNoBP(char *operand) {
  char *endptr;
  long value = strtol(operand, &endptr, 0);

  if (*endptr) {
    fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
    exit(1);
  }

  return value;
}

#define GET_STR(i) GetOperand((mnemonic), (operands), (num_opr), (i))
#define GET_LONG(i, bp_type) GetOperandLong(\
    GetOperand((mnemonic), (operands), (num_opr), (i)), \
    (backpatches), &(num_backpatches), (ip), (bp_type))
#define GET_LONG_NO_BP(i) GetOperandLongNoBP(\
    GetOperand((mnemonic), (operands), (num_opr), (i)))

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

  uint16_t insn[1024 * 2];
  int ip = ORIGIN;

  struct Backpatch backpatches[128];
  int num_backpatches = 0;

  struct LabelAddr labels[128];
  int num_labels = 0;

  while (fgets(line, sizeof(line), stdin) != NULL) {
    int num_opr = SplitOpcode(line, &label, &mnemonic, operands, MAX_OPERAND);

    if (label) {
      labels[num_labels].label = strdup(label);
      labels[num_labels].ip = ip;
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
      if (strchr(GET_STR(0), '+') == NULL) {
        insn[ip >> 1] = 0x8000 | (GET_LONG(0, BP_ABS15) & 0x7fffu);
      } else {
        uint16_t off;
        enum AddrBase ab = ParseAddrOffset(GET_STR(0), &off);
        insn[ip >> 1] = 0x3000 | (ab << 10) | (0x3ff & off);
      }
    } else if (strcmp(mnemonic, "jmp") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    ip, strdup(GET_STR(0)), BP_IP_REL12);
      insn[ip >> 1] = 0x0000;
    } else if (strcmp(mnemonic, "call") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    ip, strdup(GET_STR(0)), BP_IP_REL12);
      insn[ip >> 1] = 0x0001;
    } else if (strcmp(mnemonic, "jz") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    ip, strdup(GET_STR(0)), BP_IP_REL12);
      insn[ip >> 1] = 0x1000;
    } else if (strcmp(mnemonic, "jnz") == 0) {
      InitBackpatch(backpatches + num_backpatches++,
                    ip, strdup(GET_STR(0)), BP_IP_REL12);
      insn[ip >> 1] = 0x1001;
    } else if (strcmp(mnemonic, "ld") == 0) {
      uint16_t off;
      enum AddrBase ab = ParseAddrOffset(GET_STR(0), &off);
      insn[ip >> 1] = 0x2000 | (ab << 10) | (0x3fe & off);
    } else if (strcmp(mnemonic, "st") == 0) {
      uint16_t off;
      enum AddrBase ab = ParseAddrOffset(GET_STR(0), &off);
      insn[ip >> 1] = 0x2001 | (ab << 10) | (0x3fe & off);
    } else if (strcmp(mnemonic, "add") == 0) {
      if (num_opr == 0) {
        insn[ip >> 1] = 0x7060;
      } else {
        char *base = GET_STR(0);
        if (ExpectFP(base)) {
          fprintf(stderr, "base of ADD must be FP: '%s'\n", base);
          exit(1);
        }
        uint16_t addend = GET_LONG_NO_BP(1);
        insn[ip >> 1] = 0x4000 | (0x3ff & addend);
      }
    } else if (strcmp(mnemonic, "nop") == 0) {
      insn[ip >> 1] = 0x7000;
    } else if (strcmp(mnemonic, "pop") == 0) {
      if (num_opr == 0) {
        insn[ip >> 1] = 0x704f;
      } else {
        long n = GET_LONG_NO_BP(0);
        if (n == 0) {
          insn[ip >> 1] = 0x704f;
        } else if (n == 1) {
          insn[ip >> 1] = 0x7040;
        } else {
          fprintf(stderr, "POP takes 0 or 1: %ld\n", n);
          exit(1);
        }
      }
    } else if (strcmp(mnemonic, "inc") == 0) {
      insn[ip >> 1] = 0x7001;
    } else if (strcmp(mnemonic, "inc2") == 0) {
      insn[ip >> 1] = 0x7002;
    } else if (strcmp(mnemonic, "not") == 0) {
      insn[ip >> 1] = 0x7004;
    } else if (strcmp(mnemonic, "and") == 0) {
      insn[ip >> 1] = 0x7050;
    } else if (strcmp(mnemonic, "or") == 0) {
      insn[ip >> 1] = 0x7051;
    } else if (strcmp(mnemonic, "xor") == 0) {
      insn[ip >> 1] = 0x7052;
    } else if (strcmp(mnemonic, "shr") == 0) {
      insn[ip >> 1] = 0x7054;
    } else if (strcmp(mnemonic, "sar") == 0) {
      insn[ip >> 1] = 0x7055;
    } else if (strcmp(mnemonic, "shl") == 0) {
      insn[ip >> 1] = 0x7056;
    } else if (strcmp(mnemonic, "join") == 0) {
      insn[ip >> 1] = 0x7057;
    } else if (strcmp(mnemonic, "sub") == 0) {
      insn[ip >> 1] = 0x7061;
    } else if (strcmp(mnemonic, "mul") == 0) {
      insn[ip >> 1] = 0x7062;
    } else if (strcmp(mnemonic, "lt") == 0) {
      insn[ip >> 1] = 0x7068;
    } else if (strcmp(mnemonic, "eq") == 0) {
      insn[ip >> 1] = 0x7069;
    } else if (strcmp(mnemonic, "neq") == 0) {
      insn[ip >> 1] = 0x706a;
    } else if (strcmp(mnemonic, "dup") == 0) {
      if (num_opr == 0) {
        insn[ip >> 1] = 0x7080;
      } else {
        long n = GET_LONG_NO_BP(0);
        if (n == 0) {
          insn[ip >> 1] = 0x7080;
        } else if (n == 1) {
          insn[ip >> 1] = 0x708f;
        } else {
          fprintf(stderr, "DUP takes 0 or 1: %ld\n", n);
          exit(1);
        }
      }
    } else if (strcmp(mnemonic, "ret") == 0) {
      insn[ip >> 1] = 0x7800;
    } else if (strcmp(mnemonic, "cpop") == 0) {
      char *target = GET_STR(0);
      if (ExpectFP(target)) {
        fprintf(stderr, "CPOP takes FP: '%s'\n", target);
        exit(1);
      }
      insn[ip >> 1] = 0x7802;
    } else if (strcmp(mnemonic, "cpush") == 0) {
      char *target = GET_STR(0);
      if (ExpectFP(target)) {
        fprintf(stderr, "CPUSH takes FP: '%s'\n", target);
        exit(1);
      }
      insn[ip >> 1] = 0x7803;
    } else if (strcmp(mnemonic, "ldd") == 0) {
      insn[ip >> 1] = 0x7808;
    } else if (strcmp(mnemonic, "sta") == 0) { // store, remaining address
      insn[ip >> 1] = 0x780c;
    } else if (strcmp(mnemonic, "std") == 0) { // store, remaining data
      insn[ip >> 1] = 0x780e;
    } else if (strcmp(mnemonic, "db") == 0) {
      ip += DataByte(&insn[ip >> 1], operands, num_opr);
      if (ip & 1) {
        ip++;
      }
      continue;
    } else {
      fprintf(stderr, "unknown mnemonic: %s\n", mnemonic);
      exit(1);
    }

    if (postfix && strcmp(postfix, "1") == 0) {
      insn[ip >> 1] |= 0x0001;
    }

    ip += 2;
  }

  for (int i = 0; i < num_backpatches; i++) {
    int l = 0;
    for (; l < num_labels; l++) {
      if (strcmp(backpatches[i].label, labels[l].label)) {
        continue;
      }

      int ins_pc = backpatches[i].ip;
      uint16_t ins = insn[ins_pc >> 1];
      switch (backpatches[i].type) {
      case BP_IP_REL12:
        ins = (ins & 0xf001u) | ((labels[l].ip - ins_pc - 2) & 0xffeu);
        break;
      case BP_IP_REL10:
        ins = (ins & 0xfc01u) | ((labels[l].ip - ins_pc - 2) & 0x3feu);
        break;
      case BP_ABS10:
        ins = (ins & 0xfc00u) | (labels[l].ip & 0x3ffu);
        break;
      case BP_ABS15:
        ins = (ins & 0x8000u) | (labels[l].ip & 0x7fffu);
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

  for (int i = ORIGIN; i < ip; i += 2) {
    printf("%04X\n", insn[i >> 1]);
  }
  return 0;
}
