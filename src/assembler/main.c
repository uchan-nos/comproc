#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_OPERAND 128
#define ORIGIN 0x4000
#define MAX_BP 256
#define MAX_LABEL 256

// line をニーモニックとオペランドに分割する
// 戻り値: オペランドの数
int SplitOpcode(char *line, char **label, char **mnemonic, char **operands, int n) {
  if (strtok(line, ";#") == NULL) {
    return -1;
  }

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
    for (char *last = operands[i] + strlen(operands[i]) - 1;
         last > operands[i] && strchr(" \t", *last) != NULL;
         last--) {
      *last = '\0';
    }
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

void NewBackpatch(struct Backpatch *backpatches, int *num_backpatches,
                  int ip, const char *label, enum BPType bp_type) {
  if (*num_backpatches == MAX_BP) {
    fprintf(stderr, "too many backpatches\n");
    exit(1);
  }
  InitBackpatch(backpatches + (*num_backpatches)++, ip, strdup(label), bp_type);
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

// 即値付きロードストア命令
// insn: 機械語テンプレート
// opr: "X+off" 形式の文字列
// mask: 即値のビットマスク
uint16_t GenLoadStoreImm(uint16_t insn, char *operand, uint16_t mask) {
  uint16_t off;
  enum AddrBase ab = ParseAddrOffset(operand, &off);
  return insn | (ab << 10) | (mask & off);
}

enum PopReg {
  POP_FP,
  POP_IP,
  POP_ISR,
  POP_BAR,
};

enum PopReg ParsePopReg(char *opr) {
  ToLower(opr);
  if (strcmp(opr, "fp") == 0) {
    return POP_FP;
  } else if (strcmp(opr, "ip") == 0) {
    return POP_IP;
  } else if (strcmp(opr, "isr") == 0) {
    return POP_ISR;
  } else if (strcmp(opr, "bar") == 0) {
    return POP_BAR;
  }

  fprintf(stderr, "invalid register for POP X: '%s'\n", opr);
  exit(1);
}

struct Interp {
  int16_t stack[16];
};

void Push(struct Interp *interp, int16_t v) {
  for (int i = 14; i >= 0; i--) {
    interp->stack[i + 1] = interp->stack[i];
  }
  interp->stack[0] = v;
}

int16_t Pop(struct Interp *interp) {
  int16_t top = interp->stack[0];
  for (int i = 0; i <= 14; i++) {
    interp->stack[i] = interp->stack[i + 1];
  }
  return top;
}

int16_t Top(struct Interp *interp) {
  return interp->stack[0];
}

int main(int argc, char **argv) {
  int separate_output = 0;
  const char *input_filename = NULL;
  const char *output_filename = NULL;
  const char *map_filename = NULL;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--separate-output") == 0) {
      separate_output = 1;
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
    } else if (strcmp(argv[i], "--map") == 0) {
      i++;
      if (i >= argc) {
        fprintf(stderr, "map file name is not specified\n");
        exit(1);
      }
      map_filename = argv[i];
    } else {
      input_filename = argv[i];
    }
  }

  FILE *input_file = stdin;
  FILE *output_file = stdout, *output_file_hi = NULL;
  if (input_filename && strcmp(input_filename, "-") != 0) {
    input_file = fopen(input_filename, "r");
  }
  if (output_filename && strcmp(output_filename, "-") != 0) {
    if (separate_output) {
      char s[128] = {};
      strncpy(s, output_filename, 120);
      size_t l = strlen(s);
      strcpy(s + l, "_lo.hex");
      output_file = fopen(s, "w");
      strcpy(s + l, "_hi.hex");
      output_file_hi = fopen(s, "w");
    } else {
      output_file = fopen(output_filename, "w");
    }
  }

  FILE *map_file = NULL;
  if (map_filename) {
    map_file = fopen(map_filename, "w");
  }

  if (separate_output && output_file_hi == NULL) {
    fprintf(stderr, "--separate-output needs '-o <basename>'\n");
    exit(1);
  }

  char line[256];
  char *label;
  char *mnemonic;
  char *operands[MAX_OPERAND];

  uint16_t insn[1024 * 2];
  int ip = ORIGIN;

  struct Backpatch backpatches[MAX_BP];
  int num_backpatches = 0;

  struct LabelAddr labels[MAX_LABEL];
  int num_labels = 0;

  struct Interp interp;

  while (fgets(line, sizeof(line), input_file) != NULL) {
    int num_opr = SplitOpcode(line, &label, &mnemonic, operands, MAX_OPERAND);

    if (label) {
      labels[num_labels].label = strdup(label);
      labels[num_labels].ip = ip;
      num_labels++;

      if (map_file) {
        fprintf(map_file, "0x%04x %s\n", ip, label);
      }
    }

    if (num_opr < 0) {
      continue;
    }
    ToLower(mnemonic);

    uint16_t *cur_insn = &insn[(ip - ORIGIN) >> 1];

    if (mnemonic[0] == '.') {
      // 内蔵インタプリタ用命令
      if (strcmp(mnemonic + 1, "push") == 0) {
        Push(&interp, GET_LONG_NO_BP(0));
      } else if (strcmp(mnemonic + 1, "sign") == 0) {
        Push(&interp, (uint16_t)Pop(&interp) ^ 0x8000);
      } else if (strcmp(mnemonic + 1, "add") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) + rhs);
      } else if (strcmp(mnemonic + 1, "sub") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) - rhs);
      } else if (strcmp(mnemonic + 1, "mul") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) * rhs);
      } else if (strcmp(mnemonic + 1, "eq") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) == rhs);
      } else if (strcmp(mnemonic + 1, "neq") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) != rhs);
      } else if (strcmp(mnemonic + 1, "lt") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) < rhs);
      } else if (strcmp(mnemonic + 1, "le") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) <= rhs);
      } else if (strcmp(mnemonic + 1, "bt") == 0) {
        uint16_t rhs = Pop(&interp);
        Push(&interp, (uint16_t)Pop(&interp) < rhs);
      } else if (strcmp(mnemonic + 1, "be") == 0) {
        uint16_t rhs = Pop(&interp);
        Push(&interp, (uint16_t)Pop(&interp) <= rhs);
      } else if (strcmp(mnemonic + 1, "not") == 0) {
        Push(&interp, ~(uint16_t)Pop(&interp));
      } else if (strcmp(mnemonic + 1, "and") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) & rhs);
      } else if (strcmp(mnemonic + 1, "or") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) | rhs);
      } else if (strcmp(mnemonic + 1, "xor") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, Pop(&interp) ^ rhs);
      } else if (strcmp(mnemonic + 1, "shr") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, (uint16_t)Pop(&interp) >> rhs);
      } else if (strcmp(mnemonic + 1, "sar") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, (int16_t)Pop(&interp) >> rhs);
      } else if (strcmp(mnemonic + 1, "shl") == 0) {
        int16_t rhs = Pop(&interp);
        Push(&interp, (int16_t)Pop(&interp) << rhs);
      }
      continue;
    }

    if (strcmp(mnemonic, "push") == 0) {
      char *opr = GET_STR(0);
      if (strchr(opr, '+') == NULL) {
        if (opr[0] == '$') {
          if (strcmp(opr + 1, "top") == 0) {
            uint16_t stack_top = Top(&interp);
            if ((stack_top & 0x8000) == 0) {
              *cur_insn = 0x8000 | stack_top;
            } else {
              insn[(ip - ORIGIN) >> 1] = 0x8000 | (stack_top & 0x7fffu);
              ip += 2;
              insn[(ip - ORIGIN) >> 1] = 0x7005; // SIGN
            }
          } else {
            fprintf(stderr, "unknown variable: '%s'\n", opr);
            exit(1);
          }
        } else {
          *cur_insn = 0x8000 | (GET_LONG(0, BP_ABS15) & 0x7fffu);
        }
      } else {
        uint16_t off;
        enum AddrBase ab = ParseAddrOffset(GET_STR(0), &off);
        *cur_insn = 0x5000 | (ab << 10) | (0x3ff & off);
      }
    } else if (strcmp(mnemonic, "jmp") == 0) {
      NewBackpatch(backpatches, &num_backpatches, ip, GET_STR(0), BP_IP_REL12);
      *cur_insn = 0x0000;
    } else if (strcmp(mnemonic, "call") == 0) {
      if (num_opr == 0) {
        *cur_insn = 0x7801;
      } else {
        NewBackpatch(backpatches, &num_backpatches, ip, GET_STR(0), BP_IP_REL12);
        *cur_insn = 0x0001;
      }
    } else if (strcmp(mnemonic, "jz") == 0) {
      NewBackpatch(backpatches, &num_backpatches, ip, GET_STR(0), BP_IP_REL12);
      *cur_insn = 0x1000;
    } else if (strcmp(mnemonic, "jnz") == 0) {
      NewBackpatch(backpatches, &num_backpatches, ip, GET_STR(0), BP_IP_REL12);
      *cur_insn = 0x1001;
    } else if (strcmp(mnemonic, "ld1") == 0) {
      *cur_insn = GenLoadStoreImm(0x2000, GET_STR(0), 0x3ff);
    } else if (strcmp(mnemonic, "st1") == 0) {
      *cur_insn = GenLoadStoreImm(0x3000, GET_STR(0), 0x3ff);
    } else if (strcmp(mnemonic, "ld") == 0) {
      *cur_insn = GenLoadStoreImm(0x4000, GET_STR(0), 0x3fe);
    } else if (strcmp(mnemonic, "st") == 0) {
      *cur_insn = GenLoadStoreImm(0x4001, GET_STR(0), 0x3fe);
    } else if (strcmp(mnemonic, "add") == 0) {
      if (num_opr == 0) {
        *cur_insn = 0x7060;
      } else {
        char *base = GET_STR(0);
        if (ExpectFP(base)) {
          fprintf(stderr, "base of ADD must be FP: '%s'\n", base);
          exit(1);
        }
        uint16_t addend = GET_LONG_NO_BP(1);
        *cur_insn = 0x6400 | (0x3ff & addend);
      }
    } else if (strcmp(mnemonic, "nop") == 0) {
      *cur_insn = 0x7000;
    } else if (strcmp(mnemonic, "pop") == 0) {
      if (num_opr == 0) {
        *cur_insn = 0x704f;
      } else {
        enum PopReg pr = ParsePopReg(GET_STR(0));
        *cur_insn = 0x7820 | pr;
      }
    } else if (strcmp(mnemonic, "inc") == 0) {
      *cur_insn = 0x7001;
    } else if (strcmp(mnemonic, "inc2") == 0) {
      *cur_insn = 0x7002;
    } else if (strcmp(mnemonic, "not") == 0) {
      *cur_insn = 0x7004;
    } else if (strcmp(mnemonic, "sign") == 0) {
      *cur_insn = 0x7005;
    } else if (strcmp(mnemonic, "exts") == 0) {
      *cur_insn = 0x7006;
    } else if (strcmp(mnemonic, "and") == 0) {
      *cur_insn = 0x7050;
    } else if (strcmp(mnemonic, "or") == 0) {
      *cur_insn = 0x7051;
    } else if (strcmp(mnemonic, "xor") == 0) {
      *cur_insn = 0x7052;
    } else if (strcmp(mnemonic, "shr") == 0) {
      *cur_insn = 0x7054;
    } else if (strcmp(mnemonic, "sar") == 0) {
      *cur_insn = 0x7055;
    } else if (strcmp(mnemonic, "shl") == 0) {
      *cur_insn = 0x7056;
    } else if (strcmp(mnemonic, "sub") == 0) {
      *cur_insn = 0x7061;
    } else if (strcmp(mnemonic, "mul") == 0) {
      *cur_insn = 0x7062;
    } else if (strcmp(mnemonic, "eq") == 0) {
      *cur_insn = 0x7068;
    } else if (strcmp(mnemonic, "neq") == 0) {
      *cur_insn = 0x7069;
    } else if (strcmp(mnemonic, "lt") == 0) {
      *cur_insn = 0x706a;
    } else if (strcmp(mnemonic, "le") == 0) {
      *cur_insn = 0x706b;
    } else if (strcmp(mnemonic, "bt") == 0) {
      *cur_insn = 0x706c;
    } else if (strcmp(mnemonic, "be") == 0) {
      *cur_insn = 0x706d;
    } else if (strcmp(mnemonic, "dup") == 0) {
      if (num_opr == 0) {
        *cur_insn = 0x7080;
      } else {
        long n = GET_LONG_NO_BP(0);
        if (n == 0) {
          *cur_insn = 0x7080;
        } else if (n == 1) {
          *cur_insn = 0x708f;
        } else {
          fprintf(stderr, "DUP takes 0 or 1: %ld\n", n);
          exit(1);
        }
      }
    } else if (strcmp(mnemonic, "ret") == 0) {
      *cur_insn = 0x7800;
    } else if (strcmp(mnemonic, "cpop") == 0) {
      char *target = GET_STR(0);
      if (ExpectFP(target)) {
        fprintf(stderr, "CPOP takes FP: '%s'\n", target);
        exit(1);
      }
      *cur_insn = 0x7802;
    } else if (strcmp(mnemonic, "cpush") == 0) {
      char *target = GET_STR(0);
      if (ExpectFP(target)) {
        fprintf(stderr, "CPUSH takes FP: '%s'\n", target);
        exit(1);
      }
      *cur_insn = 0x7803;
    } else if (strcmp(mnemonic, "ldd") == 0) {
      *cur_insn = 0x7808;
    } else if (strcmp(mnemonic, "ldd1") == 0) {
      *cur_insn = 0x7809;
    } else if (strcmp(mnemonic, "sta") == 0) { // store, remaining address
      *cur_insn = 0x780c;
    } else if (strcmp(mnemonic, "sta1") == 0) { // store, remaining address
      *cur_insn = 0x780d;
    } else if (strcmp(mnemonic, "std") == 0) { // store, remaining data
      *cur_insn = 0x780e;
    } else if (strcmp(mnemonic, "std1") == 0) { // store, remaining data
      *cur_insn = 0x780f;
    } else if (strcmp(mnemonic, "db") == 0) {
      ip += DataByte(&*cur_insn, operands, num_opr);
      if (ip & 1) {
        ip++;
      }
      continue;
    } else if (strcmp(mnemonic, "int") == 0) {
      *cur_insn = 0x7810;
    } else if (strcmp(mnemonic, "iret") == 0) {
      *cur_insn = 0x7812;
    } else {
      fprintf(stderr, "unknown mnemonic: %s\n", mnemonic);
      exit(1);
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
      uint16_t ins = insn[(ins_pc - ORIGIN) >> 1];
      int diff_pc = labels[l].ip - ins_pc - 2;
      switch (backpatches[i].type) {
      case BP_IP_REL12:
        if (diff_pc < -0x0800 || 0x0800 <= diff_pc) {
          fprintf(stderr, "jump target is too far (BP_IP_REL12): diff=%d\n", diff_pc);
          exit(1);
        }
        ins = (ins & 0xf001u) | (diff_pc & 0xffeu);
        break;
      case BP_IP_REL10:
        if (diff_pc < -0x0200 || 0x200 <= diff_pc) {
          fprintf(stderr, "jump target is too far (BP_IP_REL10): diff=%d\n", diff_pc);
          exit(1);
        }
        ins = (ins & 0xfc01u) | (diff_pc & 0x3feu);
        break;
      case BP_ABS10:
        ins = (ins & 0xfc00u) | (labels[l].ip & 0x3ffu);
        break;
      case BP_ABS15:
        ins = (ins & 0x8000u) | (labels[l].ip & 0x7fffu);
        break;
      }
      insn[(ins_pc - ORIGIN) >> 1] = ins;
      break;
    }
    if (l == num_labels) {
      fprintf(stderr, "unknown label: %s\n", backpatches[i].label);
      exit(1);
    }
  }

  for (int i = 0; i < ip - ORIGIN; i += 2) {
    uint16_t ins = insn[i >> 1];
    if (separate_output) {
      fprintf(output_file, "%02X\n", ins & 0xffu);
      fprintf(output_file_hi, "%02X\n", ins >> 8);
    } else {
      fprintf(output_file, "%02X %02X\n", ins >> 8, ins & 0xffu);
    }
  }
  return 0;
}
