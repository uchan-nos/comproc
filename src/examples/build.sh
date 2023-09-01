#!/bin/sh

cat - | ../compiler/ucc -o - - | ../assembler/uasm
