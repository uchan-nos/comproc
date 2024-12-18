#!/bin/sh -u

if [ $# -lt 2 ]
then
  echo "Usage: $0 <src file> <commit1> [<commit2> ...]"
  exit 1
fi

tool_dir=$(dirname $0)
num_diff=$(git diff | wc -l)

src="$1"
shift
commits="$@"

if [ ! -f "$src" ]
then
  echo "No such file: $src"
  exit 1
fi

for commit in $commits
do
  git log --oneline $commit -1
done

current_branch=$(git branch --show-current)
current_commit=$(git rev-parse HEAD)

# まずワークツリーをビルドする

make -C ../compiler >/dev/null
make -C ../assembler >/dev/null
$tool_dir/build.sh $src >/dev/null

# git checkout に備えて diff を無くす
if [ $num_diff -ne 0 ]
then
  git stash save
fi

for commit in $commits
do
  git checkout -q $commit
  new_src=$(basename $src .c).$commit.c
  cp $src $new_src

  make -C ../compiler >/dev/null
  make -C ../assembler >/dev/null
  $tool_dir/build.sh $new_src >/dev/null
done

# ワークツリーを復元する

if [ "$current_branch" != "" ]
then
  git checkout -q $current_branch
else
  git checkout -q $current_commit
fi

if [ $num_diff -ne 0 ]
then
  git stash pop
fi

mode="num_insn"
echo "Mode: $mode"

case $mode in
  num_insn)
    wc -l $(basename $src .c).pmem.hex
    for commit in $commits
    do
      wc -l $(basename $src .c).$commit.pmem.hex
    done
    ;;
  diff_asm)
    for commit in $commits
    do
      diff -u $(basename $src .c).$commit.s $(basename $src .c).s
    done
    ;;
esac
