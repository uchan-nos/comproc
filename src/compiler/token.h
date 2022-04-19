#pragma once

enum TokenKind {
  // 0 - 127 は 1 文字演算子用に予約
  kTokenInteger = 128,
  kTokenReturn,
  kTokenInt,
  kTokenId,
  kTokenIf,
  kTokenElse,
  kTokenCompAssign,
  kTokenInc = kTokenCompAssign + 128,
  kTokenDec,
  kTokenFor,
  kTokenEOF,
};

struct Token {
  int kind;            // トークンの種類
  char *raw;           // トークン文字列（ソースコード文字列へのポインタ）
  int len;             // トークン文字列の長さ
  struct Token *next;

  union {
    int as_int;        // kTokenInteger
  } value;             // トークンの値
};

extern struct Token *cur_token;

void Tokenize(char *src);
struct Token *Consume(int kind);
struct Token *Expect(int kind);
