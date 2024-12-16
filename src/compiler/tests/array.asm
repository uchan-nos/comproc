section .data

section .text
start:
	call main
	st 6
fin:
	jmp fin
main:
	add fp,-8
	push 3
	st1 fp+0
	push 5
	st1 fp+1
	push 2
	st fp+2
	push 3
	st fp+4
	push fp+1
	ldd1
	push fp+4
	ldd
	sub
	add fp,8
	ret
