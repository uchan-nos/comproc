#!/bin/sh

cat - | ../compiler/ucc -o - - --ast
