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
	ld1 fp+1
	ld fp+4
	sub
	add fp,8
	ret
