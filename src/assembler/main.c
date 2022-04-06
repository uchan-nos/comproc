#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// line をニーモニックとオペランドに分割する
// 戻り値: オペランドの数
int SplitOpcode(char *line, char **mnemonic, char **operands, int n) {
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

// i 番目のオペランドを long 値として取得
long GetOperandLong(char *mnemonic, char **operands, int n, int i) {
  if (n <= i) {
    fprintf(stderr, "too few operands for '%s': %d\n", mnemonic, n);
    exit(1);
  }

  char *endptr;
  long value = strtol(operands[i], &endptr, 0);
  if (*endptr) {
    fprintf(stderr, "failed conversion to long: '%s'\n", endptr);
    exit(1);
  }

  return value;
}

#define GET_LONG(i) GetOperandLong((mnemonic), (operands), (num_opr), (i))

int main(void) {
  char line[256];
  char* mnemonic;
  char* operands[3];

  while (fgets(line, sizeof(line), stdin) != NULL) {
    int num_opr = SplitOpcode(line, &mnemonic, operands, 3);
    ToLower(mnemonic);

    if (strcmp(mnemonic, "push") == 0) {
      printf("a1%02x\n", (uint8_t)GET_LONG(0));
    } else if (strcmp(mnemonic, "ld") == 0) {
      printf("b9%02x\n", (uint8_t)GET_LONG(0));
    } else if (strcmp(mnemonic, "st") == 0) {
      printf("96%02x\n", (uint8_t)GET_LONG(0));
    } else if (strcmp(mnemonic, "sta") == 0) {
      printf("0600\n");
    } else if (strcmp(mnemonic, "std") == 0) {
      printf("1600\n");
    } else if (strcmp(mnemonic, "add") == 0) {
      printf("2202\n");
    } else if (strcmp(mnemonic, "sub") == 0) {
      printf("2203\n");
    } else if (strcmp(mnemonic, "mul") == 0) {
      printf("2204\n");
    } else if (strcmp(mnemonic, "lt") == 0) {
      printf("2208\n");
    } else {
      fprintf(stderr, "unknown mnemonic: %s\n", mnemonic);
      exit(1);
    }
  }
  return 0;
}
