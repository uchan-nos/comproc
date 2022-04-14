#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

// i 番目のオペランドを文字列として取得
char *GetOperand(char *mnemonic, char **operands, int n, int i) {
  if (n <= i) {
    fprintf(stderr, "too few operands for '%s': %d\n", mnemonic, n);
    exit(1);
  }
  return operands[i];
}

// i 番目のオペランドを long 値として取得
long GetOperandLong(char *mnemonic, char **operands, int n, int i) {
  char *endptr;
  long value = strtol(GetOperand(mnemonic, operands, n, i), &endptr, 0);
  if (*endptr) {
    fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
    exit(1);
  }

  return value;
}

#define GET_STR(i) GetOperand((mnemonic), (operands), (num_opr), (i))
#define GET_LONG(i) GetOperandLong((mnemonic), (operands), (num_opr), (i))

struct LabelAddr {
  const char *label;
  uint8_t pc;
};

int main(void) {
  char line[256];
  char *label;
  char *mnemonic;
  char *operands[3];

  uint16_t insn[256];
  uint8_t pc = 0;

  struct LabelAddr backpatches[128];
  int num_backpatches = 0;

  struct LabelAddr labels[128];
  int num_labels = 0;

  while (fgets(line, sizeof(line), stdin) != NULL) {
    int num_opr = SplitOpcode(line, &label, &mnemonic, operands, 3);

    if (label) {
      labels[num_labels].label = strdup(label);
      labels[num_labels].pc = pc;
      num_labels++;
    }

    if (num_opr < 0) {
      continue;
    }
    ToLower(mnemonic);

    if (strcmp(mnemonic, "push") == 0) {
      insn[pc] = 0x0000 | (uint8_t)GET_LONG(0);
    } else if (strcmp(mnemonic, "ld") == 0) {
      insn[pc] = 0x0800 | (uint8_t)GET_LONG(0);
    } else if (strcmp(mnemonic, "st") == 0) {
      insn[pc] = 0x0c00 | (uint8_t)GET_LONG(0);
    } else if (strcmp(mnemonic, "sta") == 0) { // store, remaining address
      insn[pc] = 0x0d00;
    } else if (strcmp(mnemonic, "std") == 0) { // store, remaining data
      insn[pc] = 0x0e00;
    } else if (strcmp(mnemonic, "add") == 0) {
      insn[pc] = 0x2002;
    } else if (strcmp(mnemonic, "sub") == 0) {
      insn[pc] = 0x2003;
    } else if (strcmp(mnemonic, "mul") == 0) {
      insn[pc] = 0x2004;
    } else if (strcmp(mnemonic, "lt") == 0) {
      insn[pc] = 0x2008;
    } else if (strcmp(mnemonic, "jz") == 0) {
      backpatches[num_backpatches].label = strdup(GET_STR(0));
      backpatches[num_backpatches].pc = pc;
      num_backpatches++;
      insn[pc] = 0x1000;
    } else {
      fprintf(stderr, "unknown mnemonic: %s\n", mnemonic);
      exit(1);
    }

    pc++;
  }

  for (int i = 0; i < num_backpatches; i++) {
    int l = 0;
    for (; l < num_labels; l++) {
      if (strcmp(backpatches[i].label, labels[l].label) == 0) {
        insn[backpatches[i].pc] |= labels[l].pc;
        break;
      }
    }
    if (l == num_labels) {
      fprintf(stderr, "unknown label: %s\n", backpatches[i].label);
      exit(1);
    }
  }

  for (int i = 0; i < pc; i++) {
    printf("%04x\n", insn[i]);
  }
  return 0;
}
